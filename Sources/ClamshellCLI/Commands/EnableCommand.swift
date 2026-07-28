import ArgumentParser

struct EnableCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "enable",
    abstract: "Allow clamshell mode while using battery power."
  )

  @OptionGroup var output: OutputOptions

  func run() throws {
    let result = try CommandComposition.clamshellService().set(.enabled)
    Console(isQuiet: output.quiet).writeTransition(result)
  }
}
