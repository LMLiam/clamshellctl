import SwiftUI
import WidgetKit

struct BatteryClamshellControl: ControlWidget {
  static let kind = "uk.co.lmliam.clamshell.control.battery"

  var body: some ControlWidgetConfiguration {
    StaticControlConfiguration(kind: Self.kind, provider: Provider()) { isEnabled in
      ControlWidgetToggle(isOn: isEnabled, action: SetBatteryClamshellIntent()) {
        Label("Battery Clamshell Mode", systemImage: "laptopcomputer")
      }
    }
    .displayName("Battery Clamshell Mode")
    .description("Allow clamshell mode while the Mac uses battery power.")
  }
}

private struct Provider: ControlValueProvider {
  let previewValue = false

  func currentValue() async throws -> Bool {
    false
  }
}
