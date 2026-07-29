public struct TimerPaths: Equatable, Sendable {
  public let launchAgentPath: String
  public let metadataPath: String

  public init(homeDirectory: String) {
    launchAgentPath =
      "\(homeDirectory)/Library/LaunchAgents/\(TimerController.label).plist"
    metadataPath =
      "\(homeDirectory)/Library/Application Support/clamshellctl/timer.json"
  }
}
