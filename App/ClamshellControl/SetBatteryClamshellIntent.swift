import AppIntents
import ClamshellControlModel
import WidgetKit

struct SetBatteryClamshellIntent: SetValueIntent {
  static let title: LocalizedStringResource = "Set battery clamshell mode"
  static let supportedModes: IntentModes = .background

  @Parameter(title: "Enabled")
  var value: Bool

  init() {}

  func perform() async throws -> some IntentResult {
    try ControlModel.live.setValue(value)
    ControlCenter.shared.reloadControls(ofKind: BatteryClamshellControl.kind)
    return .result()
  }
}
