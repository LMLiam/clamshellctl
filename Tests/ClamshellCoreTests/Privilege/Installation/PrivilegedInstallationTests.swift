import Foundation
import Testing

@testable import ClamshellCore

@Suite("Privileged installation")
struct PrivilegedInstallationTests {
    @Test("installs the helper and validated policy in order")
    func install() throws {
        let log = InstallationOperationLog()
        let source = "/tmp/build/clamshellctl-helper"
        let fileSystem = RecordingInstallationFileSystem(
            files: [source: "helper payload"],
            log: log
        )
        let runner = InstallationRecordingRunner(
            result: ProcessResult(
                standardOutput: "",
                standardError: "",
                terminationStatus: 0
            ),
            log: log
        )
        let installation = PrivilegedInstallation(
            fileSystem: fileSystem,
            runner: runner,
            effectiveUserID: 0,
            environment: ["SUDO_USER": "liam"],
            executablePath: "/tmp/build/clamshellctl",
            temporarySuffix: "test"
        )

        let result = try installation.install()

        let helperTemporary = "\(PrivilegedPaths.helper).installing.test"
        let policyTemporary = "\(PrivilegedPaths.sudoersPolicy).installing.test"
        #expect(
            result
                == InstallationResult(
                    helperPath: PrivilegedPaths.helper,
                    sudoersPolicyPath: PrivilegedPaths.sudoersPolicy
                )
        )
        #expect(
            log.operations == [
                .isRegularFile(source),
                .isRegularFile(PrivilegedPaths.helper),
                .copy(source: source, destination: helperTemporary),
                .setOwner(path: helperTemporary, userID: 0, groupID: 0),
                .setPermissions(path: helperTemporary, permissions: 0o755),
                .replace(replacement: helperTemporary, destination: PrivilegedPaths.helper),
                .write(
                    contents: try SudoersPolicy(username: "liam").contents,
                    path: policyTemporary
                ),
                .setOwner(path: policyTemporary, userID: 0, groupID: 0),
                .setPermissions(path: policyTemporary, permissions: 0o440),
                .run(
                    executable: "/usr/sbin/visudo",
                    arguments: ["-cf", policyTemporary]
                ),
                .replace(
                    replacement: policyTemporary,
                    destination: PrivilegedPaths.sudoersPolicy
                ),
                .isRegularFile(PrivilegedPaths.helper),
                .contentsEqual(
                    firstPath: source,
                    secondPath: PrivilegedPaths.helper
                ),
                .attributes(PrivilegedPaths.helper),
                .isRegularFile(PrivilegedPaths.sudoersPolicy),
                .readText(PrivilegedPaths.sudoersPolicy),
                .attributes(PrivilegedPaths.sudoersPolicy),
                .run(
                    executable: "/usr/sbin/visudo",
                    arguments: ["-cf", PrivilegedPaths.sudoersPolicy]
                ),
            ]
        )
    }

    @Test("finds a Homebrew libexec payload beside the installation prefix")
    func homebrewPayload() throws {
        let log = InstallationOperationLog()
        let source = "/opt/homebrew/Cellar/clamshellctl/0.1.0/libexec/clamshellctl-helper"
        let fileSystem = RecordingInstallationFileSystem(
            files: [source: "helper payload"],
            log: log
        )
        let runner = InstallationRecordingRunner(result: .success, log: log)
        let installation = PrivilegedInstallation(
            fileSystem: fileSystem,
            runner: runner,
            effectiveUserID: 0,
            environment: ["SUDO_USER": "liam"],
            executablePath: "/opt/homebrew/Cellar/clamshellctl/0.1.0/bin/clamshellctl",
            temporarySuffix: "test"
        )

        _ = try installation.install()

        #expect(
            Array(log.operations.prefix(4)) == [
                .isRegularFile(
                    "/opt/homebrew/Cellar/clamshellctl/0.1.0/bin/clamshellctl-helper"
                ),
                .isRegularFile(source),
                .isRegularFile(PrivilegedPaths.helper),
                .copy(
                    source: source,
                    destination: "\(PrivilegedPaths.helper).installing.test"
                ),
            ]
        )
    }

    @Test("recognises an already verified installation")
    func alreadyInstalled() throws {
        let log = InstallationOperationLog()
        let source = "/tmp/build/clamshellctl-helper"
        let fileSystem = RecordingInstallationFileSystem(
            files: [source: "helper payload"],
            log: log
        )
        let runner = InstallationRecordingRunner(result: .success, log: log)
        let installation = PrivilegedInstallation(
            fileSystem: fileSystem,
            runner: runner,
            effectiveUserID: 0,
            environment: ["SUDO_USER": "liam"],
            executablePath: "/tmp/build/clamshellctl",
            temporarySuffix: "test"
        )

        let first = try installation.install()
        let operationCount = log.operations.count
        let second = try installation.install()
        let repeatedOperations = Array(log.operations.dropFirst(operationCount))

        #expect(first.didChange)
        #expect(!second.didChange)
        #expect(
            !repeatedOperations.contains { operation in
                switch operation {
                case .copy, .write, .replace:
                    true
                default:
                    false
                }
            })
    }

    @Test("rejects setup before file access when not running as root")
    func rootRequired() {
        let log = InstallationOperationLog()
        let installation = PrivilegedInstallation(
            fileSystem: RecordingInstallationFileSystem(files: [:], log: log),
            runner: InstallationRecordingRunner(result: .success, log: log),
            effectiveUserID: 501,
            environment: ["SUDO_USER": "liam"],
            executablePath: "/tmp/build/clamshellctl",
            temporarySuffix: "test"
        )

        #expect(
            throws: ClamshellError.administratorPrivilegesRequired(
                command: PrivilegedHelperClient.setupCommand
            )
        ) {
            try installation.install()
        }
        #expect(log.operations.isEmpty)
    }

    @Test("requires the original sudo user")
    func originalUserRequired() {
        let log = InstallationOperationLog()
        let installation = PrivilegedInstallation(
            fileSystem: RecordingInstallationFileSystem(files: [:], log: log),
            runner: InstallationRecordingRunner(result: .success, log: log),
            effectiveUserID: 0,
            environment: [:],
            executablePath: "/tmp/build/clamshellctl",
            temporarySuffix: "test"
        )

        #expect(throws: ClamshellError.originalUserUnavailable) {
            try installation.install()
        }
        #expect(log.operations.isEmpty)
    }

    @Test("keeps the existing policy when visudo rejects the replacement")
    func failedValidation() {
        let log = InstallationOperationLog()
        let source = "/tmp/build/clamshellctl-helper"
        let fileSystem = RecordingInstallationFileSystem(
            files: [
                source: "helper payload",
                PrivilegedPaths.sudoersPolicy: "existing policy",
            ],
            log: log
        )
        let runner = InstallationRecordingRunner(
            result: ProcessResult(
                standardOutput: "",
                standardError: "syntax error",
                terminationStatus: 1
            ),
            log: log
        )
        let installation = PrivilegedInstallation(
            fileSystem: fileSystem,
            runner: runner,
            effectiveUserID: 0,
            environment: ["SUDO_USER": "liam"],
            executablePath: "/tmp/build/clamshellctl",
            temporarySuffix: "test"
        )

        #expect(throws: ClamshellError.sudoersValidationFailed) {
            try installation.install()
        }
        #expect(fileSystem.contents(at: PrivilegedPaths.sudoersPolicy) == "existing policy")
        #expect(
            !log.operations.contains(
                .replace(
                    replacement: "\(PrivilegedPaths.sudoersPolicy).installing.test",
                    destination: PrivilegedPaths.sudoersPolicy
                )
            )
        )
    }

    @Test("removes only managed paths and is safe to repeat")
    func uninstall() throws {
        let log = InstallationOperationLog()
        let unrelated = "/usr/local/bin/clamshellctl"
        let fileSystem = RecordingInstallationFileSystem(
            files: [
                PrivilegedPaths.helper: "helper",
                PrivilegedPaths.sudoersPolicy: "policy",
                unrelated: "unrelated",
            ],
            log: log
        )
        let installation = PrivilegedInstallation(
            fileSystem: fileSystem,
            runner: InstallationRecordingRunner(result: .success, log: log),
            effectiveUserID: 0,
            environment: [:],
            executablePath: "/tmp/build/clamshellctl",
            temporarySuffix: "test"
        )

        let first = try installation.uninstall()
        let second = try installation.uninstall()

        #expect(first.removedPaths == [PrivilegedPaths.helper, PrivilegedPaths.sudoersPolicy])
        #expect(second.removedPaths.isEmpty)
        #expect(fileSystem.contents(at: unrelated) == "unrelated")
    }
}
