import Darwin
import Foundation

public protocol InstallationFileSystem: Sendable {
    func itemExists(at path: String) -> Bool
    func isRegularFile(at path: String) -> Bool
    func copyItem(at source: String, to destination: String) throws
    func write(_ contents: String, to path: String) throws
    func setOwner(userID: UInt32, groupID: UInt32, at path: String) throws
    func setPermissions(_ permissions: UInt16, at path: String) throws
    func replaceItem(at destination: String, withItemAt replacement: String) throws
    func removeItem(at path: String) throws
}

public struct FoundationInstallationFileSystem: InstallationFileSystem {
    public init() {}

    public func itemExists(at path: String) -> Bool {
        var information = stat()
        return path.withCString { lstat($0, &information) == 0 }
    }

    public func isRegularFile(at path: String) -> Bool {
        guard
            let attributes = try? FileManager.default.attributesOfItem(atPath: path),
            let type = attributes[.type] as? FileAttributeType
        else {
            return false
        }
        return type == .typeRegular
    }

    public func copyItem(at source: String, to destination: String) throws {
        try FileManager.default.copyItem(atPath: source, toPath: destination)
    }

    public func write(_ contents: String, to path: String) throws {
        try Data(contents.utf8).write(to: URL(fileURLWithPath: path))
    }

    public func setOwner(userID: UInt32, groupID: UInt32, at path: String) throws {
        guard chown(path, userID, groupID) == 0 else {
            throw currentPOSIXError()
        }
    }

    public func setPermissions(_ permissions: UInt16, at path: String) throws {
        guard chmod(path, mode_t(permissions)) == 0 else {
            throw currentPOSIXError()
        }
    }

    public func replaceItem(at destination: String, withItemAt replacement: String) throws {
        guard rename(replacement, destination) == 0 else {
            throw currentPOSIXError()
        }
    }

    public func removeItem(at path: String) throws {
        guard itemExists(at: path) else {
            return
        }
        try FileManager.default.removeItem(atPath: path)
    }

    private func currentPOSIXError() -> POSIXError {
        POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
    }
}

public struct InstallationResult: Sendable, Equatable {
    public let helperPath: String
    public let sudoersPolicyPath: String

    public init(helperPath: String, sudoersPolicyPath: String) {
        self.helperPath = helperPath
        self.sudoersPolicyPath = sudoersPolicyPath
    }
}

public struct UninstallationResult: Sendable, Equatable {
    public let removedPaths: [String]

    public init(removedPaths: [String]) {
        self.removedPaths = removedPaths
    }
}

public struct PrivilegedInstallation: Sendable {
    private let fileSystem: any InstallationFileSystem
    private let runner: any ProcessRunning
    private let effectiveUserID: UInt32
    private let environment: [String: String]
    private let executablePath: String
    private let temporarySuffix: String

    public init(
        fileSystem: any InstallationFileSystem,
        runner: any ProcessRunning,
        effectiveUserID: UInt32,
        environment: [String: String],
        executablePath: String,
        temporarySuffix: String = UUID().uuidString
    ) {
        self.fileSystem = fileSystem
        self.runner = runner
        self.effectiveUserID = effectiveUserID
        self.environment = environment
        self.executablePath = executablePath
        self.temporarySuffix = temporarySuffix
    }

    public func install() throws -> InstallationResult {
        try requireAdministratorPrivileges()

        guard let originalUser = environment["SUDO_USER"], !originalUser.isEmpty else {
            throw ClamshellError.originalUserUnavailable
        }
        let policy = try SudoersPolicy(username: originalUser)
        let payload = try helperPayloadPath()

        let helperTemporary = temporaryPath(for: PrivilegedPaths.helper)
        var helperTemporaryExists = false
        defer {
            if helperTemporaryExists {
                try? fileSystem.removeItem(at: helperTemporary)
            }
        }

        try fileSystem.copyItem(at: payload, to: helperTemporary)
        helperTemporaryExists = true
        try fileSystem.setOwner(userID: 0, groupID: 0, at: helperTemporary)
        try fileSystem.setPermissions(0o755, at: helperTemporary)
        try fileSystem.replaceItem(
            at: PrivilegedPaths.helper,
            withItemAt: helperTemporary
        )
        helperTemporaryExists = false

        let policyTemporary = temporaryPath(for: PrivilegedPaths.sudoersPolicy)
        var policyTemporaryExists = false
        defer {
            if policyTemporaryExists {
                try? fileSystem.removeItem(at: policyTemporary)
            }
        }

        try fileSystem.write(policy.contents, to: policyTemporary)
        policyTemporaryExists = true
        try fileSystem.setPermissions(0o440, at: policyTemporary)

        let validation = try runner.run(
            "/usr/sbin/visudo",
            arguments: ["-cf", policyTemporary]
        )
        guard validation.terminationStatus == 0 else {
            throw ClamshellError.sudoersValidationFailed
        }

        try fileSystem.replaceItem(
            at: PrivilegedPaths.sudoersPolicy,
            withItemAt: policyTemporary
        )
        policyTemporaryExists = false

        return InstallationResult(
            helperPath: PrivilegedPaths.helper,
            sudoersPolicyPath: PrivilegedPaths.sudoersPolicy
        )
    }

    public func uninstall() throws -> UninstallationResult {
        try requireAdministratorPrivileges()

        var removedPaths: [String] = []
        for path in [PrivilegedPaths.helper, PrivilegedPaths.sudoersPolicy]
        where fileSystem.itemExists(at: path) {
            try fileSystem.removeItem(at: path)
            removedPaths.append(path)
        }
        return UninstallationResult(removedPaths: removedPaths)
    }

    private func requireAdministratorPrivileges() throws {
        guard effectiveUserID == 0 else {
            throw ClamshellError.administratorPrivilegesRequired(
                command: PrivilegedHelperClient.setupCommand
            )
        }
    }

    private func helperPayloadPath() throws -> String {
        let executable = URL(fileURLWithPath: executablePath).standardizedFileURL
        let executableDirectory = executable.deletingLastPathComponent()
        var candidates = [
            executableDirectory.appendingPathComponent("clamshellctl-helper").path
        ]

        if executableDirectory.lastPathComponent == "bin" {
            candidates.append(
                executableDirectory
                    .deletingLastPathComponent()
                    .appendingPathComponent("libexec/clamshellctl-helper")
                    .path
            )
        }

        guard let payload = candidates.first(where: fileSystem.isRegularFile(at:)) else {
            throw ClamshellError.helperPayloadNotFound
        }
        return payload
    }

    private func temporaryPath(for destination: String) -> String {
        "\(destination).installing.\(temporarySuffix)"
    }
}
