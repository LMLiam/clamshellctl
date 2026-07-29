import Foundation
import Testing
import ClamshellControlProtocol

@Suite("Control action request")
struct ControlActionRequestTests {
  @Test("maps each request to one exact URL")
  func exactURLs() {
    #expect(
      ControlActionRequest.enableBatteryClamshellMode.url.absoluteString
        == "clamshellctl://battery-clamshell/enable"
    )
    #expect(
      ControlActionRequest.disableBatteryClamshellMode.url.absoluteString
        == "clamshellctl://battery-clamshell/disable"
    )
  }

  @Test("parses both exact URLs")
  func validURLs() throws {
    let enableURL = try #require(
      URL(string: "clamshellctl://battery-clamshell/enable")
    )
    let disableURL = try #require(
      URL(string: "clamshellctl://battery-clamshell/disable")
    )

    #expect(ControlActionRequest(url: enableURL) == .enableBatteryClamshellMode)
    #expect(ControlActionRequest(url: disableURL) == .disableBatteryClamshellMode)
  }

  @Test(
    "rejects every URL outside the exact contract",
    arguments: [
      "other://battery-clamshell/enable",
      "clamshellctl://other/enable",
      "clamshellctl://battery-clamshell/toggle",
      "clamshellctl://battery-clamshell/enable?command=other",
      "clamshellctl://battery-clamshell/enable#other",
      "clamshellctl://user@battery-clamshell/enable",
    ]
  )
  func invalidURL(value: String) throws {
    let url = try #require(URL(string: value))
    #expect(ControlActionRequest(url: url) == nil)
  }
}
