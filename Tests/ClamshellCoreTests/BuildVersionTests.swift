import Testing

@testable import ClamshellCore

@Suite("Build version")
struct BuildVersionTests {
  @Test("uses a three-component semantic version")
  func semanticVersion() {
    let components = BuildVersion.current.split(
      separator: ".",
      omittingEmptySubsequences: false
    )

    #expect(components.count == 3)
    #expect(components.allSatisfy { UInt($0) != nil })
  }
}
