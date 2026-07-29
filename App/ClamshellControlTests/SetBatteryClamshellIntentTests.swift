import AppIntents
import ClamshellControlIntent
import Testing

@Suite("Battery clamshell intent")
struct SetBatteryClamshellIntentTests {
  @Test("runs in the control extension")
  func extensionExecution() {
    #expect(SetBatteryClamshellIntent.supportedModes == .background)
  }
}
