import Testing

@testable import Clamshell

@Suite("Setup state")
struct SetupStateTests {
  @Test("allows removal when an incomplete bundle still contains the CLI")
  func recoverableIncompleteBundle() {
    let state = SetupState.missingBundlePayload(commandAvailable: true)

    #expect(state.allowsPrivilegedRemoval)
    #expect(!state.allowsSetup)
  }

  @Test("requires reinstallation when an incomplete bundle has no CLI")
  func unrecoverableIncompleteBundle() {
    let state = SetupState.missingBundlePayload(commandAvailable: false)

    #expect(!state.allowsPrivilegedRemoval)
    #expect(!state.allowsSetup)
  }
}
