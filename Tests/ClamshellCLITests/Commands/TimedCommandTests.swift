import ArgumentParser
import Foundation
import Testing

@testable import ClamshellCLI
@testable import ClamshellCore

@Suite("Timed commands")
struct TimedCommandTests {
  private let executablePath = "/usr/local/bin/clamshellctl"
  private let now = Date(timeIntervalSince1970: 1_800_000_000)

  @Test("enable parses a bounded duration")
  func parsesDuration() throws {
    let command = try #require(
      try ClamshellCommand.parseAsRoot([
        "enable",
        "--for",
        "2h",
        "--quiet",
      ]) as? EnableCommand
    )

    #expect(command.duration?.seconds == 7_200)
  }

  @Test("timed enablement changes state before it installs the timer")
  func enableThenSchedule() throws {
    let log = CommandOperationLog()
    let power = RecordingPowerState(initial: .disabled, log: log)
    let timer = timerFixture(log: log)
    let command = try enableCommand(duration: "2h")

    try command.run(
      service: service(power),
      timerController: timer.controller,
      now: now,
      executablePath: executablePath
    )

    #expect(
      log.entries == [
        .state(.enabled),
        .launchctl("bootstrap"),
      ])
    #expect(
      try timer.controller.metadata()?.deadline
        == now.addingTimeInterval(7_200)
    )
  }

  @Test("a scheduling failure rolls back a new enabled state")
  func scheduleRollback() throws {
    let power = RecordingPowerState(initial: .disabled)
    let timer = timerFixture()
    timer.runner.results = [launchctlFailure()]
    let command = try enableCommand(duration: "2h")

    #expect(throws: ClamshellError.self) {
      try command.run(
        service: service(power),
        timerController: timer.controller,
        now: now,
        executablePath: executablePath
      )
    }

    #expect(power.mutations == [.enabled, .disabled])
    #expect(power.state == .disabled)
  }

  @Test("a rollback failure reports both failures")
  func failedRollback() throws {
    let power = RecordingPowerState(
      initial: .disabled,
      failedState: .disabled
    )
    let timer = timerFixture()
    timer.runner.results = [launchctlFailure()]
    let command = try enableCommand(duration: "2h")

    #expect(
      throws: ClamshellError.timedEnablementRollbackFailed(
        scheduling: "/bin/launchctl exited with status 5. Bootstrap failed",
        rollback: "Rollback failed."
      )
    ) {
      try command.run(
        service: service(power),
        timerController: timer.controller,
        now: now,
        executablePath: executablePath
      )
    }
  }

  @Test("permanent enablement cancels an existing timer")
  func permanentEnablement() throws {
    let power = RecordingPowerState(initial: .enabled)
    let timer = try scheduledTimer()
    let command = try enableCommand(duration: nil)

    try command.run(
      service: service(power),
      timerController: timer.controller,
      now: now,
      executablePath: executablePath
    )

    #expect(try timer.controller.metadata() == nil)
  }

  @Test("manual disablement cancels an existing timer")
  func disableCancelsTimer() throws {
    let power = RecordingPowerState(initial: .enabled)
    let timer = try scheduledTimer()
    let command = try #require(
      try ClamshellCommand.parseAsRoot(["disable", "--quiet"])
        as? DisableCommand
    )

    try command.run(
      service: service(power),
      timerController: timer.controller
    )

    #expect(power.state == .disabled)
    #expect(try timer.controller.metadata() == nil)
  }

  @Test("status displays an active deadline")
  func activeStatus() throws {
    let power = RecordingPowerState(initial: .enabled)
    let timer = try scheduledTimer()
    let pipe = Pipe()
    let command = try #require(
      try ClamshellCommand.parseAsRoot(["status"]) as? StatusCommand
    )

    try command.run(
      stateReader: power,
      timerController: timer.controller,
      now: now,
      console: Console(
        isQuiet: false,
        standardOutput: pipe.fileHandleForWriting
      )
    )
    try pipe.fileHandleForWriting.close()
    let output = try #require(
      String(
        data: pipe.fileHandleForReading.readDataToEndOfFile(),
        encoding: .utf8
      )
    )

    #expect(output.contains("Battery clamshell mode: enabled\n"))
    #expect(output.contains("Temporary enablement ends: 2027-01-15T10:00:00Z\n"))
  }

  @Test("the internal timer command is hidden from help")
  func hiddenTimerCommand() {
    #expect(!ClamshellCommand.helpMessage().contains("timer-check"))
  }

  @Test("the internal timer command reconciles an expired timer")
  func timerCheck() throws {
    let power = RecordingPowerState(initial: .enabled)
    let timer = try scheduledTimer()
    let command = try #require(
      try ClamshellCommand.parseAsRoot(["timer-check"])
        as? TimerCheckCommand
    )

    try command.run(
      service: service(power),
      timerController: timer.controller,
      now: now.addingTimeInterval(7_200)
    )

    #expect(power.state == .disabled)
    #expect(try timer.controller.metadata() == nil)
  }

  @Test("enable help documents the duration grammar and limit")
  func durationHelp() {
    let help = EnableCommand.helpMessage()

    #expect(help.contains("--for <duration>"))
    #expect(help.contains("whole minutes (m), hours (h),"))
    #expect(help.contains("or days (d)"))
    #expect(help.contains("30 days"))
  }

  private func enableCommand(duration: String?) throws -> EnableCommand {
    var arguments = ["enable", "--quiet"]
    if let duration {
      arguments.append(contentsOf: ["--for", duration])
    }
    return try #require(
      try ClamshellCommand.parseAsRoot(arguments) as? EnableCommand
    )
  }

  private func service(_ power: RecordingPowerState) -> ClamshellService {
    ClamshellService(stateReader: power, stateWriter: power)
  }

  private func scheduledTimer() throws -> CommandTimerFixture {
    let timer = timerFixture()
    try timer.controller.schedule(
      TimerMetadata(
        deadline: now.addingTimeInterval(7_200),
        executablePath: executablePath
      )
    )
    timer.runner.invocations.removeAll()
    return timer
  }

  private func timerFixture(
    log: CommandOperationLog? = nil
  ) -> CommandTimerFixture {
    let homeDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
      .path
    let runner = CommandProcessRunner(log: log)
    return CommandTimerFixture(
      controller: TimerController(
        paths: TimerPaths(homeDirectory: homeDirectory),
        userID: 501,
        fileSystem: FoundationTimerFileSystem(),
        runner: runner
      ),
      runner: runner,
      homeDirectory: homeDirectory
    )
  }

  private func launchctlFailure() -> ProcessResult {
    ProcessResult(
      standardOutput: "",
      standardError: "Bootstrap failed",
      terminationStatus: 5
    )
  }
}

private enum CommandTestError: LocalizedError {
  case rollbackFailed

  var errorDescription: String? {
    "Rollback failed."
  }
}

private enum CommandOperation: Equatable {
  case launchctl(String)
  case state(ClamshellState)
}

private final class CommandOperationLog: @unchecked Sendable {
  var entries: [CommandOperation] = []
}

private final class RecordingPowerState:
  PowerStateReading,
  PowerStateWriting,
  @unchecked Sendable
{
  var state: ClamshellState
  var mutations: [ClamshellState] = []

  private let failedState: ClamshellState?
  private let log: CommandOperationLog?

  init(
    initial state: ClamshellState,
    failedState: ClamshellState? = nil,
    log: CommandOperationLog? = nil
  ) {
    self.state = state
    self.failedState = failedState
    self.log = log
  }

  func currentState() throws -> ClamshellState {
    state
  }

  func setState(_ state: ClamshellState) throws {
    mutations.append(state)
    log?.entries.append(.state(state))
    guard state != failedState else {
      throw CommandTestError.rollbackFailed
    }
    self.state = state
  }
}

private struct CommandProcessInvocation: Equatable {
  let executable: String
  let arguments: [String]
}

private final class CommandProcessRunner: ProcessRunning, @unchecked Sendable {
  var invocations: [CommandProcessInvocation] = []
  var results: [ProcessResult] = []

  private let log: CommandOperationLog?

  init(log: CommandOperationLog?) {
    self.log = log
  }

  func run(_ executable: String, arguments: [String]) throws -> ProcessResult {
    invocations.append(
      CommandProcessInvocation(executable: executable, arguments: arguments)
    )
    log?.entries.append(.launchctl(arguments[0]))
    return results.isEmpty
      ? ProcessResult(standardOutput: "", standardError: "", terminationStatus: 0)
      : results.removeFirst()
  }
}

private final class CommandTimerFixture: @unchecked Sendable {
  let controller: TimerController
  let runner: CommandProcessRunner

  private let homeDirectory: String

  init(
    controller: TimerController,
    runner: CommandProcessRunner,
    homeDirectory: String
  ) {
    self.controller = controller
    self.runner = runner
    self.homeDirectory = homeDirectory
  }

  deinit {
    try? FileManager.default.removeItem(atPath: homeDirectory)
  }
}
