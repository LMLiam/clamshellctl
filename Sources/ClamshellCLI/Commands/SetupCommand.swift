import ArgumentParser
import ClamshellCore

struct SetupCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "setup",
    abstract: "Install the restricted privileged helper."
  )

  @OptionGroup var output: OutputOptions

  func run() throws {
    try run(installation: CommandComposition.privilegedInstallation())
  }

  func run(installation: PrivilegedInstallation) throws {
    let result = try installation.install()
    let console = Console(isQuiet: output.quiet)

    if result.didChange {
      console.writeLine("Privileged setup installed:")
      console.writeLine(result.helperPath)
      console.writeLine(result.sudoersPolicyPath)
    } else {
      console.writeLine("Privileged setup: already configured")
    }
  }
}
