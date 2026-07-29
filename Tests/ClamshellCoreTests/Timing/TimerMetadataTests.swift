import Foundation
import Testing

@testable import ClamshellCore

@Suite("Timer metadata")
struct TimerMetadataTests {
  private let deadline = Date(timeIntervalSince1970: 1_800_000_000)
  private let executablePath = "/usr/local/bin/clamshellctl"

  @Test("round trips through stable JSON")
  func roundTrip() throws {
    let metadata = try TimerMetadata(
      deadline: deadline,
      executablePath: executablePath
    )

    let data = try metadata.encoded()
    let json = try #require(String(data: data, encoding: .utf8))

    #expect(
      json
        == #"{"deadline":"2027-01-15T08:00:00Z","executablePath":"/usr/local/bin/clamshellctl","schemaVersion":1}"#
    )
    #expect(try TimerMetadata(decoding: data) == metadata)
  }

  @Test("rejects an unknown schema version")
  func unknownSchema() {
    let data = Data(
      #"{"deadline":"2027-01-15T08:00:00Z","executablePath":"/usr/local/bin/clamshellctl","schemaVersion":2}"#
        .utf8
    )

    #expect(throws: ClamshellError.unsupportedTimerMetadataVersion(2)) {
      try TimerMetadata(decoding: data)
    }
  }

  @Test("rejects a relative executable path when created")
  func relativePathOnCreation() {
    #expect(throws: ClamshellError.invalidTimerExecutablePath("bin/clamshellctl")) {
      try TimerMetadata(
        deadline: deadline,
        executablePath: "bin/clamshellctl"
      )
    }
  }

  @Test("rejects a relative executable path when decoded")
  func relativePathOnDecode() {
    let data = Data(
      #"{"deadline":"2027-01-15T08:00:00Z","executablePath":"bin/clamshellctl","schemaVersion":1}"#
        .utf8
    )

    #expect(throws: ClamshellError.invalidTimerExecutablePath("bin/clamshellctl")) {
      try TimerMetadata(decoding: data)
    }
  }
}
