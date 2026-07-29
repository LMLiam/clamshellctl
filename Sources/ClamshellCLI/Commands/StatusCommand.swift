import ArgumentParser
import ClamshellCore
import Foundation

struct StatusCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "status",
    abstract: "Show the current battery clamshell mode."
  )

  func run() throws {
    try run(
      stateReader: PowerSettingsClient(runner: FoundationProcessRunner()),
      timerController: CommandComposition.timerController(),
      now: Date(),
      console: Console(isQuiet: false)
    )
  }

  func run(
    stateReader: any PowerStateReading,
    timerController: TimerController,
    now: Date,
    console: Console
  ) throws {
    let state = try stateReader.currentState()
    console.writeLine("Battery clamshell mode: \(state.rawValue)")

    guard let metadata = try timerController.metadata() else {
      return
    }
    let deadline = ISO8601DateFormatter().string(from: metadata.deadline)
    if metadata.deadline > now {
      console.writeLine("Temporary enablement ends: \(deadline)")
    } else {
      console.writeLine(
        "Temporary enablement deadline passed: \(deadline). Run clamshellctl disable."
      )
    }
  }
}
