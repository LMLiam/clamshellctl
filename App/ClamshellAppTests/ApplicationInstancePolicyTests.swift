import Foundation
import Testing

@testable import Clamshell

@Suite("Application instance policy")
struct ApplicationInstancePolicyTests {
  private let installedURL = URL(fileURLWithPath: "/Applications/Clamshell.app")
  private let debugURL = URL(fileURLWithPath: "/tmp/DerivedData/Clamshell.app")

  @Test("keeps the installed app when a Debug copy is newer")
  func installedAppPriority() {
    let current = instance(processIdentifier: 10, bundleURL: installedURL, launchedAt: 1)
    let debug = instance(processIdentifier: 20, bundleURL: debugURL, launchedAt: 2)

    let resolution = ApplicationInstancePolicy().resolve(
      current: current,
      running: [current, debug]
    )

    #expect(resolution == .continueAndTerminate([20]))
  }

  @Test("terminates a Debug copy when the installed app is running")
  func debugCopyTermination() {
    let installed = instance(processIdentifier: 10, bundleURL: installedURL, launchedAt: 1)
    let current = instance(processIdentifier: 20, bundleURL: debugURL, launchedAt: 2)

    let resolution = ApplicationInstancePolicy().resolve(
      current: current,
      running: [installed, current]
    )

    #expect(resolution == .terminateCurrent)
  }

  @Test("keeps the newest copy when paths have equal priority")
  func newestLaunch() {
    let older = instance(processIdentifier: 10, bundleURL: debugURL, launchedAt: 1)
    let current = instance(processIdentifier: 20, bundleURL: debugURL, launchedAt: 2)

    let resolution = ApplicationInstancePolicy().resolve(
      current: current,
      running: [older, current]
    )

    #expect(resolution == .continueAndTerminate([10]))
  }

  @Test("uses the process identifier to resolve a launch-date tie")
  func processIdentifierTieBreak() {
    let olderProcess = instance(processIdentifier: 10, bundleURL: debugURL, launchedAt: 1)
    let current = instance(processIdentifier: 20, bundleURL: debugURL, launchedAt: 1)

    let resolution = ApplicationInstancePolicy().resolve(
      current: current,
      running: [olderProcess, current]
    )

    #expect(resolution == .continueAndTerminate([10]))
  }

  private func instance(
    processIdentifier: Int32,
    bundleURL: URL,
    launchedAt: TimeInterval
  ) -> ApplicationInstancePolicy.Instance {
    ApplicationInstancePolicy.Instance(
      processIdentifier: processIdentifier,
      bundleURL: bundleURL,
      launchDate: Date(timeIntervalSince1970: launchedAt)
    )
  }
}
