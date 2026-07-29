import ArgumentParser
import ClamshellCore

struct UninstallCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "uninstall",
    abstract: "Remove the restricted privileged helper."
  )

  @OptionGroup var output: OutputOptions

  @Flag(help: "Remove the app-bundled command link when this app owns it.")
  var removeCommand = false

  func run() throws {
    try run(installation: CommandComposition.privilegedInstallation())
  }

  func run(installation: PrivilegedInstallation) throws {
    let result = try installation.uninstall(removeCommand: removeCommand)
    let console = Console(isQuiet: output.quiet)

    guard !result.removedPaths.isEmpty else {
      console.writeLine("Privileged setup: already removed")
      return
    }

    console.writeLine("Privileged setup removed:")
    for path in result.removedPaths {
      console.writeLine(path)
    }
  }
}
