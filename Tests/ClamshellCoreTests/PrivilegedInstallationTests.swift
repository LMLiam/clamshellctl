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

private enum InstallationOperation: Equatable {
    case itemExists(String)
    case isRegularFile(String)
    case contentsEqual(firstPath: String, secondPath: String)
    case readText(String)
    case attributes(String)
    case copy(source: String, destination: String)
    case setOwner(path: String, userID: UInt32, groupID: UInt32)
    case setPermissions(path: String, permissions: UInt16)
    case replace(replacement: String, destination: String)
    case write(contents: String, path: String)
    case remove(String)
    case run(executable: String, arguments: [String])
}

private final class InstallationOperationLog: @unchecked Sendable {
    private let lock = NSLock()
    private var recordedOperations: [InstallationOperation] = []

    var operations: [InstallationOperation] {
        lock.withLock { recordedOperations }
    }

    func append(_ operation: InstallationOperation) {
        lock.withLock {
            recordedOperations.append(operation)
        }
    }
}

private final class RecordingInstallationFileSystem:
    InstallationFileSystem,
    @unchecked Sendable
{
    private let lock = NSLock()
    private let log: InstallationOperationLog
    private var files: [String: String]
    private var fileAttributes: [String: InstalledFileAttributes]

    init(files: [String: String], log: InstallationOperationLog) {
        self.files = files
        fileAttributes = Dictionary(
            uniqueKeysWithValues: files.keys.map {
                ($0, InstalledFileAttributes(userID: 501, groupID: 20, permissions: 0o755))
            }
        )
        self.log = log
    }

    func itemExists(at path: String) -> Bool {
        log.append(.itemExists(path))
        return lock.withLock { files[path] != nil }
    }

    func isRegularFile(at path: String) -> Bool {
        log.append(.isRegularFile(path))
        return lock.withLock { files[path] != nil }
    }

    func contentsEqual(at firstPath: String, and secondPath: String) -> Bool {
        log.append(.contentsEqual(firstPath: firstPath, secondPath: secondPath))
        return lock.withLock { files[firstPath] == files[secondPath] }
    }

    func readText(at path: String) throws -> String {
        log.append(.readText(path))
        return try lock.withLock {
            guard let contents = files[path] else {
                throw ClamshellError.installationVerificationFailed
            }
            return contents
        }
    }

    func attributes(at path: String) throws -> InstalledFileAttributes {
        log.append(.attributes(path))
        return try lock.withLock {
            guard let attributes = fileAttributes[path] else {
                throw ClamshellError.installationVerificationFailed
            }
            return attributes
        }
    }

    func copyItem(at source: String, to destination: String) throws {
        log.append(.copy(source: source, destination: destination))
        try lock.withLock {
            guard let contents = files[source] else {
                throw ClamshellError.helperPayloadNotFound
            }
            files[destination] = contents
            fileAttributes[destination] = fileAttributes[source]
        }
    }

    func write(_ contents: String, to path: String) throws {
        log.append(.write(contents: contents, path: path))
        lock.withLock {
            files[path] = contents
            fileAttributes[path] = InstalledFileAttributes(
                userID: 0,
                groupID: 0,
                permissions: 0o600
            )
        }
    }

    func setOwner(userID: UInt32, groupID: UInt32, at path: String) throws {
        log.append(.setOwner(path: path, userID: userID, groupID: groupID))
        try lock.withLock {
            guard let attributes = fileAttributes[path] else {
                throw ClamshellError.installationVerificationFailed
            }
            fileAttributes[path] = InstalledFileAttributes(
                userID: userID,
                groupID: groupID,
                permissions: attributes.permissions
            )
        }
    }

    func setPermissions(_ permissions: UInt16, at path: String) throws {
        log.append(.setPermissions(path: path, permissions: permissions))
        try lock.withLock {
            guard let attributes = fileAttributes[path] else {
                throw ClamshellError.installationVerificationFailed
            }
            fileAttributes[path] = InstalledFileAttributes(
                userID: attributes.userID,
                groupID: attributes.groupID,
                permissions: permissions
            )
        }
    }

    func replaceItem(at destination: String, withItemAt replacement: String) throws {
        log.append(.replace(replacement: replacement, destination: destination))
        try lock.withLock {
            guard let contents = files.removeValue(forKey: replacement) else {
                throw ClamshellError.helperPayloadNotFound
            }
            files[destination] = contents
            fileAttributes[destination] = fileAttributes.removeValue(forKey: replacement)
        }
    }

    func removeItem(at path: String) throws {
        log.append(.remove(path))
        lock.withLock {
            _ = files.removeValue(forKey: path)
            _ = fileAttributes.removeValue(forKey: path)
        }
    }

    func contents(at path: String) -> String? {
        lock.withLock { files[path] }
    }
}

private final class InstallationRecordingRunner: ProcessRunning, @unchecked Sendable {
    private let result: ProcessResult
    private let log: InstallationOperationLog

    init(result: ProcessResult, log: InstallationOperationLog) {
        self.result = result
        self.log = log
    }

    func run(_ executable: String, arguments: [String]) throws -> ProcessResult {
        log.append(.run(executable: executable, arguments: arguments))
        return result
    }
}

extension ProcessResult {
    fileprivate static let success = ProcessResult(
        standardOutput: "",
        standardError: "",
        terminationStatus: 0
    )
}
