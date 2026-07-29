import AppIntents
import ClamshellControlProtocol

public struct SetBatteryClamshellIntent: SetValueIntent {
  public static let title: LocalizedStringResource = "Set battery clamshell mode"
  public static let supportedModes: IntentModes = .background

  @Parameter(title: "Enabled")
  public var value: Bool

  public init() {}

  public func perform() async throws -> some IntentResult {
    let request: ControlActionRequest =
      value ? .enableBatteryClamshellMode : .disableBatteryClamshellMode
    try await WorkspaceControlActionRequester.live.request(request)
    return .result()
  }
}
