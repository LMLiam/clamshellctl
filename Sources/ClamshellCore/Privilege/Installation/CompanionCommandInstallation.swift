import Foundation

struct CompanionCommandInstallation: Sendable {
  private static let executablePath = "/Applications/Clamshell.app/Contents/MacOS/clamshellctl"

  private let fileSystem: any InstallationFileSystem
  private let sourceExecutablePath: String

  init(fileSystem: any InstallationFileSystem, sourceExecutablePath: String) {
    self.fileSystem = fileSystem
    self.sourceExecutablePath = sourceExecutablePath
  }

  func preflightExposure() throws {
    guard isCompanionExecutable else {
      throw ClamshellError.companionExecutableRequired
    }

    if let destination = fileSystem.symbolicLinkDestination(at: PrivilegedPaths.cliLink) {
      guard URL(fileURLWithPath: destination).standardizedFileURL.path == Self.executablePath
      else {
        throw ClamshellError.cliLinkConflict
      }
      return
    }
    guard !fileSystem.itemExists(at: PrivilegedPaths.cliLink) else {
      throw ClamshellError.cliLinkConflict
    }
  }

  func expose() throws -> Bool {
    try preflightExposure()

    if fileSystem.symbolicLinkDestination(at: PrivilegedPaths.cliLink) != nil {
      return false
    }
    guard !fileSystem.itemExists(at: PrivilegedPaths.cliLink) else {
      throw ClamshellError.cliLinkConflict
    }

    try fileSystem.createSymbolicLink(
      at: PrivilegedPaths.cliLink,
      destination: Self.executablePath
    )
    return true
  }

  func removeIfManaged() throws -> Bool {
    guard
      isCompanionExecutable,
      fileSystem.symbolicLinkDestination(at: PrivilegedPaths.cliLink) == Self.executablePath
    else {
      return false
    }

    try fileSystem.removeItem(at: PrivilegedPaths.cliLink)
    return true
  }

  private var isCompanionExecutable: Bool {
    URL(fileURLWithPath: sourceExecutablePath).standardizedFileURL.path == Self.executablePath
  }
}
