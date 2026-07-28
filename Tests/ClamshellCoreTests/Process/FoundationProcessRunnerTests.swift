import Testing

@testable import ClamshellCore

@Suite("Foundation process runner")
struct FoundationProcessRunnerTests {
  @Test("captures separate output streams and the exit status")
  func capturesProcessResult() throws {
    let result = try FoundationProcessRunner().run(
      "/bin/sh",
      arguments: ["-c", "printf output; printf error >&2; exit 7"]
    )

    #expect(
      result
        == ProcessResult(
          standardOutput: "output",
          standardError: "error",
          terminationStatus: 7
        )
    )
  }
}
