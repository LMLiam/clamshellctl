import Foundation
import Testing

@testable import ClamshellCore

@Suite("Timer controller")
struct TimerControllerTests {
  private let homeDirectory = "/Users/test"
  private let userID: UInt32 = 501
  private let executablePath = "/usr/local/bin/clamshellctl"
  private let deadline = Date(timeIntervalSince1970: 1_800_000_000)

  @Test("creates metadata and a one-shot LaunchAgent")
  func create() throws {
    let context = context()
    let metadata = try timerMetadata()

    try context.controller.schedule(metadata)

    #expect(try context.controller.metadata() == metadata)
    #expect(
      context.fileSystem.atomicWrites == [
        context.paths.metadataPath,
        context.paths.launchAgentPath,
      ])
    #expect(
      context.runner.invocations == [
        ProcessInvocation(
          executable: "/bin/launchctl",
          arguments: [
            "bootstrap",
            "gui/501",
            context.paths.launchAgentPath,
          ]
        )
      ])

    let plist = try context.launchAgentPropertyList()
    #expect(plist["Label"] as? String == TimerController.label)
    #expect(
      plist["ProgramArguments"] as? [String]
        == [executablePath, "timer-check"]
    )
    #expect(plist["RunAtLoad"] as? Bool == true)
    #expect(
      plist["StartCalendarInterval"] as? [String: Int]
        == [
          "Year": 2027,
          "Month": 1,
          "Day": 15,
          "Hour": 8,
          "Minute": 0,
          "Second": 0,
        ]
    )
  }

  @Test("unloads an existing agent before it writes the replacement")
  func replace() throws {
    let log = OperationLog()
    let context = context(log: log)
    context.fileSystem.files[context.paths.launchAgentPath] = Data()
    context.fileSystem.files[context.paths.metadataPath] = Data()

    try context.controller.schedule(timerMetadata())

    #expect(
      log.entries == [
        .process("bootout"),
        .remove(context.paths.launchAgentPath),
        .remove(context.paths.metadataPath),
        .write(context.paths.metadataPath),
        .write(context.paths.launchAgentPath),
        .process("bootstrap"),
      ])
  }

  @Test("cancels only the managed agent and timer files")
  func cancel() throws {
    let context = context()
    let unrelatedPath = "\(homeDirectory)/Library/LaunchAgents/example.plist"
    context.fileSystem.files = [
      context.paths.launchAgentPath: Data(),
      context.paths.metadataPath: Data(),
      unrelatedPath: Data(),
    ]

    try context.controller.cancel()

    #expect(
      context.runner.invocations == [
        ProcessInvocation(
          executable: "/bin/launchctl",
          arguments: [
            "bootout",
            "gui/501",
            context.paths.launchAgentPath,
          ]
        )
      ])
    #expect(context.fileSystem.files[context.paths.launchAgentPath] == nil)
    #expect(context.fileSystem.files[context.paths.metadataPath] == nil)
    #expect(context.fileSystem.files[unrelatedPath] == Data())
  }

  @Test("does not disable before the deadline")
  func beforeDeadline() throws {
    let context = try scheduledContext()
    var disableCount = 0

    try context.controller.reconcile(
      at: deadline.addingTimeInterval(-1)
    ) {
      disableCount += 1
    }

    #expect(disableCount == 0)
    #expect(context.fileSystem.files[context.paths.metadataPath] != nil)
  }

  @Test("disables and cancels at the deadline")
  func atDeadline() throws {
    let context = try scheduledContext()
    var disableCount = 0

    try context.controller.reconcile(at: deadline) {
      disableCount += 1
    }

    #expect(disableCount == 1)
    #expect(context.fileSystem.files[context.paths.launchAgentPath] == nil)
    #expect(context.fileSystem.files[context.paths.metadataPath] == nil)
  }

  @Test("removes timer files before it unloads its own agent")
  func selfCancellationOrder() throws {
    let log = OperationLog()
    let context = context(log: log)
    try context.controller.schedule(timerMetadata())
    log.entries.removeAll()

    try context.controller.reconcile(at: deadline) {}

    #expect(
      log.entries == [
        .remove(context.paths.launchAgentPath),
        .remove(context.paths.metadataPath),
        .process("bootout"),
      ])
    #expect(
      context.runner.invocations.last?.arguments == [
        "bootout",
        "gui/501/\(TimerController.label)",
      ])
  }

  @Test("reconciles a missed deadline from persisted metadata")
  func missedDeadline() throws {
    let context = context()
    context.fileSystem.files[context.paths.launchAgentPath] = Data()
    context.fileSystem.files[context.paths.metadataPath] = try timerMetadata().encoded()
    var disableCount = 0

    try context.controller.reconcile(
      at: deadline.addingTimeInterval(60)
    ) {
      disableCount += 1
    }

    #expect(disableCount == 1)
    #expect(context.fileSystem.files.isEmpty)
  }

  @Test("removes an orphaned agent before it unloads itself")
  func orphanedAgent() throws {
    let log = OperationLog()
    let context = context(log: log)
    context.fileSystem.files[context.paths.launchAgentPath] = Data()

    try context.controller.reconcile(at: deadline) {
      Issue.record("Disablement must not run without timer metadata")
    }

    #expect(
      log.entries == [
        .remove(context.paths.launchAgentPath),
        .process("bootout"),
      ])
    #expect(
      context.runner.invocations.last?.arguments == [
        "bootout",
        "gui/501/\(TimerController.label)",
      ])
  }

  @Test("keeps metadata when disablement fails")
  func disableFailure() throws {
    let context = try scheduledContext()

    #expect(throws: TestError.disableFailed) {
      try context.controller.reconcile(at: deadline) {
        throw TestError.disableFailed
      }
    }

    #expect(context.fileSystem.files[context.paths.metadataPath] != nil)
  }

  @Test("removes both files when one cleanup operation fails")
  func cleanupFailure() throws {
    let context = try scheduledContext()
    context.fileSystem.removeFailures.insert(context.paths.launchAgentPath)

    #expect(
      throws: ClamshellError.timerCleanupFailed(context.paths.launchAgentPath)
    ) {
      try context.controller.cancel()
    }

    #expect(
      context.fileSystem.removalAttempts == [
        context.paths.launchAgentPath,
        context.paths.metadataPath,
      ])
    #expect(context.fileSystem.files[context.paths.metadataPath] == nil)
  }

  @Test("removes new files when launchd rejects the schedule")
  func bootstrapFailure() throws {
    let context = context()
    context.runner.results = [
      ProcessResult(
        standardOutput: "",
        standardError: "Bootstrap failed",
        terminationStatus: 5
      )
    ]

    #expect(
      throws: ClamshellError.processFailed(
        executable: "/bin/launchctl",
        terminationStatus: 5,
        standardError: "Bootstrap failed"
      )
    ) {
      try context.controller.schedule(timerMetadata())
    }

    #expect(context.fileSystem.files.isEmpty)
  }

  private func scheduledContext() throws -> TimerTestContext {
    let context = context()
    try context.controller.schedule(timerMetadata())
    context.runner.invocations.removeAll()
    return context
  }

  private func timerMetadata() throws -> TimerMetadata {
    try TimerMetadata(
      deadline: deadline,
      executablePath: executablePath
    )
  }

  private func context(log: OperationLog? = nil) -> TimerTestContext {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt

    let paths = TimerPaths(homeDirectory: homeDirectory)
    let fileSystem = RecordingTimerFileSystem(log: log)
    let runner = RecordingTimerProcessRunner(log: log)
    let controller = TimerController(
      paths: paths,
      userID: userID,
      calendar: calendar,
      fileSystem: fileSystem,
      runner: runner
    )
    return TimerTestContext(
      controller: controller,
      paths: paths,
      fileSystem: fileSystem,
      runner: runner
    )
  }
}

private struct TimerTestContext {
  let controller: TimerController
  let paths: TimerPaths
  let fileSystem: RecordingTimerFileSystem
  let runner: RecordingTimerProcessRunner

  func launchAgentPropertyList() throws -> [String: Any] {
    let data = try #require(fileSystem.files[paths.launchAgentPath])
    return try #require(
      PropertyListSerialization.propertyList(from: data, format: nil)
        as? [String: Any]
    )
  }
}

private enum TestError: Error {
  case disableFailed
}

private enum Operation: Equatable {
  case process(String)
  case remove(String)
  case write(String)
}

private final class OperationLog: @unchecked Sendable {
  var entries: [Operation] = []
}

private struct ProcessInvocation: Equatable {
  let executable: String
  let arguments: [String]
}

private final class RecordingTimerProcessRunner: ProcessRunning, @unchecked Sendable {
  var invocations: [ProcessInvocation] = []
  var results: [ProcessResult] = []

  private let log: OperationLog?

  init(log: OperationLog?) {
    self.log = log
  }

  func run(_ executable: String, arguments: [String]) throws -> ProcessResult {
    invocations.append(ProcessInvocation(executable: executable, arguments: arguments))
    log?.entries.append(.process(arguments[0]))
    return results.isEmpty
      ? ProcessResult(standardOutput: "", standardError: "", terminationStatus: 0)
      : results.removeFirst()
  }
}

private final class RecordingTimerFileSystem: TimerFileSystem, @unchecked Sendable {
  var files: [String: Data] = [:]
  var atomicWrites: [String] = []
  var removalAttempts: [String] = []
  var removeFailures: Set<String> = []

  private let log: OperationLog?

  init(log: OperationLog?) {
    self.log = log
  }

  func itemExists(at path: String) -> Bool {
    files[path] != nil
  }

  func readData(at path: String) throws -> Data {
    try #require(files[path])
  }

  func writeAtomically(_ data: Data, to path: String) throws {
    atomicWrites.append(path)
    log?.entries.append(.write(path))
    files[path] = data
  }

  func removeItemIfExists(at path: String) throws {
    removalAttempts.append(path)
    log?.entries.append(.remove(path))
    guard !removeFailures.contains(path) else {
      throw TestError.disableFailed
    }
    files[path] = nil
  }
}
