import ArgumentParser
import ClamshellCore
import Testing

@testable import ClamshellCLI

@Suite("Setup commands")
struct SetupCommandTests {
  @Test("setup requires an explicit administrator invocation")
  func setupRequiresRoot() throws {
    var command = try ClamshellCommand.parseAsRoot(["setup"])

    #expect(
      throws: ClamshellError.administratorPrivilegesRequired(
        command: PrivilegedHelperClient.setupCommand
      )
    ) {
      try command.run()
    }
  }

  @Test("uninstall requires an explicit administrator invocation")
  func uninstallRequiresRoot() throws {
    var command = try ClamshellCommand.parseAsRoot(["uninstall"])

    #expect(
      throws: ClamshellError.administratorPrivilegesRequired(
        command: PrivilegedHelperClient.uninstallCommand
      )
    ) {
      try command.run()
    }
  }
}
