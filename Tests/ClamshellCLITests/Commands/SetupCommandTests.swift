import ArgumentParser
import ClamshellCore
import Testing

@testable import ClamshellCLI

@Suite("Setup commands")
struct SetupCommandTests {
  @Test("setup requires an explicit administrator invocation")
  func setupRequiresRoot() throws {
    let command = try #require(try ClamshellCommand.parseAsRoot(["setup"]) as? SetupCommand)

    #expect(
      throws: ClamshellError.administratorPrivilegesRequired(
        command: PrivilegedHelperClient.setupCommand
      )
    ) {
      try command.run(installation: inertInstallation())
    }
  }

  @Test("uninstall requires an explicit administrator invocation")
  func uninstallRequiresRoot() throws {
    let command = try #require(
      try ClamshellCommand.parseAsRoot(["uninstall"]) as? UninstallCommand
    )

    #expect(
      throws: ClamshellError.administratorPrivilegesRequired(
        command: PrivilegedHelperClient.uninstallCommand
      )
    ) {
      try command.run(installation: inertInstallation())
    }
  }

  private func inertInstallation() -> PrivilegedInstallation {
    PrivilegedInstallation(
      fileSystem: InertInstallationFileSystem(),
      runner: InertProcessRunner(),
      effectiveUserID: 501,
      environment: [:],
      executablePath: "/unused"
    )
  }

  private struct InertInstallationFileSystem: InstallationFileSystem {
    func itemExists(at path: String) -> Bool { false }
    func isRegularFile(at path: String) -> Bool { false }
    func contentsEqual(at firstPath: String, and secondPath: String) -> Bool { false }
    func readText(at path: String) throws -> String { throw UnexpectedOperation() }
    func attributes(at path: String) throws -> InstalledFileAttributes {
      throw UnexpectedOperation()
    }
    func copyItem(at source: String, to destination: String) throws {
      throw UnexpectedOperation()
    }
    func write(_ contents: String, to path: String) throws { throw UnexpectedOperation() }
    func setOwner(userID: UInt32, groupID: UInt32, at path: String) throws {
      throw UnexpectedOperation()
    }
    func setPermissions(_ permissions: UInt16, at path: String) throws {
      throw UnexpectedOperation()
    }
    func replaceItem(at destination: String, withItemAt replacement: String) throws {
      throw UnexpectedOperation()
    }
    func removeItem(at path: String) throws { throw UnexpectedOperation() }
  }

  private struct InertProcessRunner: ProcessRunning {
    func run(_ executable: String, arguments: [String]) throws -> ProcessResult {
      throw UnexpectedOperation()
    }
  }

  private struct UnexpectedOperation: Error {}
}
