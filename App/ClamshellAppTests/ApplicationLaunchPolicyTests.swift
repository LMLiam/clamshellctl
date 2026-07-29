import AppKit
import Testing

@testable import Clamshell

@Suite("Application launch policy")
@MainActor
struct ApplicationLaunchPolicyTests {
  @Test("shows setup for a default user launch")
  func defaultLaunch() {
    let userInfo: [AnyHashable: Any] = [
      NSApplication.launchIsDefaultUserInfoKey: true
    ]

    #expect(ApplicationLaunchPolicy.shouldShowSetup(userInfo: userInfo))
  }

  @Test("does not show setup for a URL launch")
  func URLLaunch() {
    let userInfo: [AnyHashable: Any] = [
      NSApplication.launchIsDefaultUserInfoKey: false
    ]

    #expect(!ApplicationLaunchPolicy.shouldShowSetup(userInfo: userInfo))
  }

  @Test("shows setup when macOS does not provide a launch value")
  func missingLaunchValue() {
    #expect(ApplicationLaunchPolicy.shouldShowSetup(userInfo: nil))
  }
}
