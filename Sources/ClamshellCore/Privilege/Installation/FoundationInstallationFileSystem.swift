import Darwin
import Foundation

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

    public func contentsEqual(at firstPath: String, and secondPath: String) -> Bool {
        FileManager.default.contentsEqual(atPath: firstPath, andPath: secondPath)
    }

    public func readText(at path: String) throws -> String {
        try String(contentsOfFile: path, encoding: .utf8)
    }

    public func attributes(at path: String) throws -> InstalledFileAttributes {
        let attributes = try FileManager.default.attributesOfItem(atPath: path)
        guard
            let userID = attributes[.ownerAccountID] as? NSNumber,
            let groupID = attributes[.groupOwnerAccountID] as? NSNumber,
            let permissions = attributes[.posixPermissions] as? NSNumber
        else {
            throw ClamshellError.installationVerificationFailed
        }
        return InstalledFileAttributes(
            userID: userID.uint32Value,
            groupID: groupID.uint32Value,
            permissions: permissions.uint16Value
        )
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
