import Foundation

public struct TimerController: Sendable {
  public static let label = "io.github.lmliam.clamshellctl.timer"

  private static let launchctlPath = "/bin/launchctl"

  private let paths: TimerPaths
  private let userID: UInt32
  private let calendar: Calendar
  private let fileSystem: any TimerFileSystem
  private let runner: any ProcessRunning

  public init(
    paths: TimerPaths,
    userID: UInt32,
    calendar: Calendar = .current,
    fileSystem: any TimerFileSystem = FoundationTimerFileSystem(),
    runner: any ProcessRunning = FoundationProcessRunner()
  ) {
    self.paths = paths
    self.userID = userID
    self.calendar = calendar
    self.fileSystem = fileSystem
    self.runner = runner
  }

  public func schedule(_ metadata: TimerMetadata) throws {
    try cancel()

    do {
      try fileSystem.writeAtomically(
        metadata.encoded(),
        to: paths.metadataPath
      )
      try fileSystem.writeAtomically(
        launchAgentData(for: metadata),
        to: paths.launchAgentPath
      )
      try runLaunchctl("bootstrap")
    } catch {
      if let failedPath = removeManagedFiles() {
        throw ClamshellError.timerCleanupFailed(failedPath)
      }
      throw error
    }
  }

  public func cancel() throws {
    var launchctlError: Error?
    if fileSystem.itemExists(at: paths.launchAgentPath) {
      do {
        try runLaunchctl("bootout")
      } catch {
        launchctlError = error
      }
    }

    if let failedPath = removeManagedFiles() {
      throw ClamshellError.timerCleanupFailed(failedPath)
    }
    if let launchctlError {
      throw launchctlError
    }
  }

  public func metadata() throws -> TimerMetadata? {
    guard fileSystem.itemExists(at: paths.metadataPath) else {
      return nil
    }
    return try TimerMetadata(
      decoding: fileSystem.readData(at: paths.metadataPath)
    )
  }

  public func reconcile(
    at date: Date,
    disable: () throws -> Void
  ) throws {
    guard let metadata = try metadata() else {
      try cancelAfterReconciliation()
      return
    }
    guard date >= metadata.deadline else {
      return
    }

    try disable()
    try cancelAfterReconciliation()
  }

  private func launchAgentData(for metadata: TimerMetadata) throws -> Data {
    let components = calendar.dateComponents(
      [.year, .month, .day, .hour, .minute, .second],
      from: metadata.deadline
    )
    guard
      let year = components.year,
      let month = components.month,
      let day = components.day,
      let hour = components.hour,
      let minute = components.minute,
      let second = components.second
    else {
      throw ClamshellError.timerCalendarConversionFailed
    }

    let propertyList: [String: Any] = [
      "Label": Self.label,
      "ProgramArguments": [metadata.executablePath, "timer-check"],
      "RunAtLoad": true,
      "StartCalendarInterval": [
        "Year": year,
        "Month": month,
        "Day": day,
        "Hour": hour,
        "Minute": minute,
        "Second": second,
      ],
    ]
    return try PropertyListSerialization.data(
      fromPropertyList: propertyList,
      format: .xml,
      options: 0
    )
  }

  private func runLaunchctl(_ command: String) throws {
    try runLaunchctl([
      command,
      "gui/\(userID)",
      paths.launchAgentPath,
    ])
  }

  private func runLaunchctl(_ arguments: [String]) throws {
    let result = try runner.run(
      Self.launchctlPath,
      arguments: arguments
    )
    guard result.terminationStatus == 0 else {
      throw ClamshellError.processFailed(
        executable: Self.launchctlPath,
        terminationStatus: result.terminationStatus,
        standardError: result.standardError
      )
    }
  }

  private func cancelAfterReconciliation() throws {
    let hadLaunchAgent = fileSystem.itemExists(at: paths.launchAgentPath)
    if let failedPath = removeManagedFiles() {
      throw ClamshellError.timerCleanupFailed(failedPath)
    }
    if hadLaunchAgent {
      try runLaunchctl([
        "bootout",
        "gui/\(userID)/\(Self.label)",
      ])
    }
  }

  private func removeManagedFiles() -> String? {
    var failedPath: String?
    for path in [paths.launchAgentPath, paths.metadataPath]
    where fileSystem.itemExists(at: path) {
      do {
        try fileSystem.removeItemIfExists(at: path)
      } catch {
        failedPath = failedPath ?? path
      }
    }
    return failedPath
  }
}
