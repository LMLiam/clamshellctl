import ClamshellControlIntent
import ClamshellControlProtocol
import Foundation
import Testing

@Suite("Workspace control action requester")
struct WorkspaceControlActionRequesterTests {
  @Test("opens the exact URL for the request")
  func exactURL() async throws {
    let recorder = URLRecorder()
    let requester = WorkspaceControlActionRequester { url in
      await recorder.record(url)
    }

    try await requester.request(.enableBatteryClamshellMode)

    #expect(
      await recorder.url?.absoluteString
        == "clamshellctl://battery-clamshell/enable"
    )
  }
}

private actor URLRecorder {
  private(set) var url: URL?

  func record(_ url: URL) {
    self.url = url
  }
}
