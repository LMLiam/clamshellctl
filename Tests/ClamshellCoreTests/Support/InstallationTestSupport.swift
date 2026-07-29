import Foundation

@testable import ClamshellCore

enum InstallationOperation: Equatable {
  case itemExists(String)
  case isRegularFile(String)
  case contentsEqual(firstPath: String, secondPath: String)
  case readText(String)
  case attributes(String)
  case copy(source: String, destination: String)
  case createSymbolicLink(path: String, destination: String)
  case setOwner(path: String, userID: UInt32, groupID: UInt32)
  case setPermissions(path: String, permissions: UInt16)
  case symbolicLinkDestination(String)
  case replace(replacement: String, destination: String)
  case write(contents: String, path: String)
  case remove(String)
  case run(executable: String, arguments: [String])
}

final class InstallationOperationLog: @unchecked Sendable {
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

final class RecordingInstallationFileSystem:
  InstallationFileSystem,
  @unchecked Sendable
{
  private let lock = NSLock()
  private let log: InstallationOperationLog
  private let reportsMatchingContents: Bool
  private var files: [String: String]
  private var fileAttributes: [String: InstalledFileAttributes]
  private var symbolicLinks: [String: String]

  init(
    files: [String: String],
    symbolicLinks: [String: String] = [:],
    log: InstallationOperationLog,
    reportsMatchingContents: Bool = true
  ) {
    self.files = files
    self.symbolicLinks = symbolicLinks
    fileAttributes = Dictionary(
      uniqueKeysWithValues: files.keys.map {
        ($0, InstalledFileAttributes(userID: 501, groupID: 20, permissions: 0o755))
      }
    )
    self.log = log
    self.reportsMatchingContents = reportsMatchingContents
  }

  func itemExists(at path: String) -> Bool {
    log.append(.itemExists(path))
    return lock.withLock { files[path] != nil || symbolicLinks[path] != nil }
  }

  func isRegularFile(at path: String) -> Bool {
    log.append(.isRegularFile(path))
    return lock.withLock { files[path] != nil }
  }

  func contentsEqual(at firstPath: String, and secondPath: String) -> Bool {
    log.append(.contentsEqual(firstPath: firstPath, secondPath: secondPath))
    return reportsMatchingContents && lock.withLock { files[firstPath] == files[secondPath] }
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

  func symbolicLinkDestination(at path: String) -> String? {
    log.append(.symbolicLinkDestination(path))
    return lock.withLock { symbolicLinks[path] }
  }

  func createSymbolicLink(at path: String, destination: String) throws {
    log.append(.createSymbolicLink(path: path, destination: destination))
    try lock.withLock {
      guard files[path] == nil, symbolicLinks[path] == nil else {
        throw ClamshellError.cliLinkConflict
      }
      symbolicLinks[path] = destination
    }
  }

  func removeItem(at path: String) throws {
    log.append(.remove(path))
    lock.withLock {
      _ = files.removeValue(forKey: path)
      _ = fileAttributes.removeValue(forKey: path)
      _ = symbolicLinks.removeValue(forKey: path)
    }
  }

  func contents(at path: String) -> String? {
    lock.withLock { files[path] }
  }
}

final class InstallationRecordingRunner: ProcessRunning, @unchecked Sendable {
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
  static let success = ProcessResult(
    standardOutput: "",
    standardError: "",
    terminationStatus: 0
  )
}
