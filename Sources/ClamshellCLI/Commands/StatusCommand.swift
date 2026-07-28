import ArgumentParser
import ClamshellCore

struct StatusCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "status",
    abstract: "Show the current battery clamshell mode."
  )

  @OptionGroup var output: OutputOptions

  func run() throws {
    let client = PowerSettingsClient(runner: FoundationProcessRunner())
    let state = try client.currentState()
    Console(isQuiet: output.quiet).writeLine(
      "Battery clamshell mode: \(state.rawValue)"
    )
  }
}
