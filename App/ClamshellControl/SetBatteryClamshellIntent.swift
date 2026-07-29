import AppIntents

struct SetBatteryClamshellIntent: SetValueIntent {
  static let title: LocalizedStringResource = "Set battery clamshell mode"
  static let supportedModes: IntentModes = .background

  @Parameter(title: "Enabled")
  var value: Bool

  init() {}

  func perform() async throws -> some IntentResult {
    .result()
  }
}
