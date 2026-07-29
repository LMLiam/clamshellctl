import AppIntents
import ClamshellControlProtocol

public struct SetBatteryClamshellIntent: SetValueIntent {
  public static let title: LocalizedStringResource = "Set battery clamshell mode"
  public static let supportedModes: IntentModes = .background

  @Parameter(title: "Enabled")
  public var value: Bool

  public init() {}

  public func perform() async throws -> some IntentResult {
    try await perform(using: .live)
    return .result()
  }

  public func perform(using requester: WorkspaceControlActionRequester) async throws {
    let request: ControlActionRequest =
      value ? .enableBatteryClamshellMode : .disableBatteryClamshellMode
    try await requester.request(request)
  }
}
