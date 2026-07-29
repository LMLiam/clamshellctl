import Testing

@testable import ClamshellCLI

@Suite("Status commands")
struct StatusCommandTests {
  @Test("status rejects quiet output")
  func quietOutputIsRejected() {
    #expect(throws: Error.self) {
      _ = try ClamshellCommand.parseAsRoot(["status", "--quiet"])
    }
  }
}
