import Testing

@testable import ClamshellCore

@Suite("Enablement duration")
struct EnablementDurationTests {
  @Test(
    "accepts whole minutes, hours, and days",
    arguments: [
      ("1m", 60),
      ("30m", 1_800),
      ("1h", 3_600),
      ("2h", 7_200),
      ("1d", 86_400),
      ("30d", 2_592_000),
      ("720h", 2_592_000),
    ]
  )
  func accepted(value: String, expectedSeconds: Int) throws {
    let duration = try EnablementDuration(parsing: value)

    #expect(duration.seconds == expectedSeconds)
  }

  @Test(
    "rejects invalid or excessive values",
    arguments: [
      "0m",
      "-1m",
      "1.5h",
      "1 h",
      "1",
      "1H",
      "31d",
      "721h",
      "43201m",
      "999999999999999999999999d",
    ]
  )
  func rejected(value: String) {
    #expect(throws: ClamshellError.invalidDuration(value)) {
      try EnablementDuration(parsing: value)
    }
  }
}
