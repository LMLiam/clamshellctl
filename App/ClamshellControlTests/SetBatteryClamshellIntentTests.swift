import AppIntents
import ClamshellControlIntent
import Foundation
import Testing

@Suite("Battery clamshell intent")
struct SetBatteryClamshellIntentTests {
  @Test("runs in the control extension")
  func extensionExecution() {
    #expect(SetBatteryClamshellIntent.supportedModes == .background)
  }

  @Test("maps enabled and disabled values to exact requests")
  func requests() async throws {
    let recorder = URLRecorder()
    let enabledRequester = requester(recorder: recorder, currentValue: true)
    let disabledRequester = requester(recorder: recorder, currentValue: false)
    let intent = SetBatteryClamshellIntent()

    intent.value = true
    try await intent.perform(using: enabledRequester)
    intent.value = false
    try await intent.perform(using: disabledRequester)

    #expect(
      await recorder.values == [
        "clamshellctl://battery-clamshell/enable",
        "clamshellctl://battery-clamshell/disable",
      ]
    )
  }

  @Test("propagates relay failures")
  func relayFailure() async {
    let requester = WorkspaceControlActionRequester(
      openURL: { _ in throw IntentTestError.relayFailed },
      currentValue: { false },
      waitForRetry: {}
    )
    let intent = SetBatteryClamshellIntent()
    intent.value = true

    await #expect(throws: IntentTestError.relayFailed) {
      try await intent.perform(using: requester)
    }
  }

  private func requester(
    recorder: URLRecorder,
    currentValue: Bool
  ) -> WorkspaceControlActionRequester {
    WorkspaceControlActionRequester(
      openURL: { url in await recorder.record(url) },
      currentValue: { currentValue },
      waitForRetry: {}
    )
  }
}

private actor URLRecorder {
  private(set) var values: [String] = []

  func record(_ url: URL) {
    values.append(url.absoluteString)
  }
}

private enum IntentTestError: Error {
  case relayFailed
}
