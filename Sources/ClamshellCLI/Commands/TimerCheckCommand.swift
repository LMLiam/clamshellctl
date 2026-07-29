import ArgumentParser
import ClamshellCore
import Foundation

struct TimerCheckCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "timer-check",
    abstract: "Reconcile a temporary enablement deadline.",
    shouldDisplay: false
  )

  func run() throws {
    try run(
      service: CommandComposition.clamshellService(),
      timerController: CommandComposition.timerController(),
      now: Date()
    )
  }

  func run(
    service: ClamshellService,
    timerController: TimerController,
    now: Date
  ) throws {
    try timerController.reconcile(at: now) {
      _ = try service.set(.disabled)
    }
  }
}
