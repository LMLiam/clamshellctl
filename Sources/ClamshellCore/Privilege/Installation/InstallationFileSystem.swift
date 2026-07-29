public protocol InstallationFileSystem: Sendable {
  func itemExists(at path: String) -> Bool
  func isRegularFile(at path: String) -> Bool
  func contentsEqual(at firstPath: String, and secondPath: String) -> Bool
  func readText(at path: String) throws -> String
  func attributes(at path: String) throws -> InstalledFileAttributes
  func copyItem(at source: String, to destination: String) throws
  func write(_ contents: String, to path: String) throws
  func setOwner(userID: UInt32, groupID: UInt32, at path: String) throws
  func setPermissions(_ permissions: UInt16, at path: String) throws
  func replaceItem(at destination: String, withItemAt replacement: String) throws
  func symbolicLinkDestination(at path: String) -> String?
  func createSymbolicLink(at path: String, destination: String) throws
  func removeItem(at path: String) throws
}

public struct InstalledFileAttributes: Sendable, Equatable {
  public let userID: UInt32
  public let groupID: UInt32
  public let permissions: UInt16

  public init(userID: UInt32, groupID: UInt32, permissions: UInt16) {
    self.userID = userID
    self.groupID = groupID
    self.permissions = permissions
  }
}
