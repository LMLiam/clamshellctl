import ClamshellControlIntent
import ClamshellControlProtocol
import Foundation
import Testing

@Suite("Workspace control action requester")
struct WorkspaceControlActionRequesterTests {
  @Test("opens the exact URL for the request")
  func exactURL() async throws {
    let recorder = URLRecorder()
    let requester = WorkspaceControlActionRequester(
      openURL: { url in await recorder.record(url) },
      currentValue: { true },
      waitForRetry: {}
    )

    try await requester.request(.enableBatteryClamshellMode)

    #expect(
      await recorder.url?.absoluteString
        == "clamshellctl://battery-clamshell/enable"
    )
  }

  @Test("waits until the requested state is confirmed")
  func stateConfirmation() async throws {
    let states = StateSequence([false, true])
    let requester = WorkspaceControlActionRequester(
      openURL: { _ in },
      currentValue: { try await states.next() },
      waitForRetry: {}
    )

    try await requester.request(.enableBatteryClamshellMode)

    #expect(await states.readCount == 2)
  }

  @Test("fails when the requested state is not confirmed")
  func unconfirmedState() async {
    let requester = WorkspaceControlActionRequester(
      openURL: { _ in },
      currentValue: { false },
      waitForRetry: {},
      maximumAttempts: 1
    )

    await #expect(throws: WorkspaceControlActionError.stateNotConfirmed) {
      try await requester.request(.enableBatteryClamshellMode)
    }
  }
}

private actor URLRecorder {
  private(set) var url: URL?

  func record(_ url: URL) {
    self.url = url
  }
}

private actor StateSequence {
  private var states: [Bool]
  private(set) var readCount = 0

  init(_ states: [Bool]) {
    self.states = states
  }

  func next() throws -> Bool {
    readCount += 1
    let state = try #require(states.first)
    states.removeFirst()
    return state
  }
}
