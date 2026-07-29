import ArgumentParser
import ClamshellCore
import Foundation

struct EnableCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "enable",
    abstract: "Allow clamshell mode while using battery power."
  )

  @OptionGroup var output: OutputOptions
  @Option(
    name: .customLong("for"),
    help: ArgumentHelp(
      "Enable temporarily. Use whole minutes (m), hours (h), or days (d), up to 30 days.",
      valueName: "duration"
    ),
    transform: { try EnablementDuration(parsing: $0) }
  )
  var duration: EnablementDuration?

  func run() throws {
    try run(
      service: CommandComposition.clamshellService(),
      timerController: CommandComposition.timerController(),
      now: Date(),
      executablePath: CommandComposition.executablePath()
    )
  }

  func run(
    service: ClamshellService,
    timerController: TimerController,
    now: Date,
    executablePath: String
  ) throws {
    let result = try service.set(.enabled)

    if let duration {
      do {
        try timerController.schedule(
          TimerMetadata(
            deadline: now.addingTimeInterval(TimeInterval(duration.seconds)),
            executablePath: executablePath
          )
        )
      } catch {
        try rollback(result, service: service, schedulingError: error)
      }
    } else {
      try timerController.cancel()
    }

    Console(isQuiet: output.quiet).writeTransition(result)
  }

  private func rollback(
    _ result: TransitionResult,
    service: ClamshellService,
    schedulingError: Error
  ) throws {
    guard result.didChange else {
      throw schedulingError
    }

    do {
      _ = try service.set(.disabled)
    } catch {
      throw ClamshellError.timedEnablementRollbackFailed(
        scheduling: schedulingError.localizedDescription,
        rollback: error.localizedDescription
      )
    }
    throw schedulingError
  }
}
