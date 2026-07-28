import ArgumentParser

struct ToggleCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "toggle",
    abstract: "Switch the current battery clamshell mode."
  )

  @OptionGroup var output: OutputOptions

  func run() throws {
    let result = try CommandComposition.clamshellService().toggle()
    Console(isQuiet: output.quiet).writeTransition(result)
  }
}
