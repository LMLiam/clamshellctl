import ArgumentParser
import ClamshellCore

struct DisableCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "disable",
    abstract: "Prevent clamshell mode while using battery power."
  )

  @OptionGroup var output: OutputOptions

  func run() throws {
    try run(
      service: CommandComposition.clamshellService(),
      timerController: CommandComposition.timerController()
    )
  }

  func run(
    service: ClamshellService,
    timerController: TimerController
  ) throws {
    let result = try service.set(.disabled)
    try timerController.cancel()
    Console(isQuiet: output.quiet).writeTransition(result)
  }
}
