import ClamshellCore
import Foundation
import Testing

@testable import Clamshell

@Suite("Companion diagnostics")
struct CompanionDiagnosticsTests {
  @Test("reports a missing payload when either bundled executable is absent")
  func missingPayload() throws {
    let fixture = try CompanionBundleFixture()
    defer { fixture.remove() }
    try fixture.createCLI()

    let diagnostics = CompanionDiagnostics(
      bundleURL: fixture.bundleURL,
      installation: StubInstallationStatusReader(status: .ready)
    )

    #expect(try diagnostics.currentState() == .missingBundlePayload)
  }

  @Test(
    "maps every installation status when the bundle payload is complete",
    arguments: [
      (InstallationStatus.notInstalled, SetupState.needsSetup),
      (.ready, .ready),
      (.invalid, .invalidHelper),
    ]
  )
  func installationStatus(status: InstallationStatus, expectedState: SetupState) throws {
    let fixture = try CompanionBundleFixture()
    defer { fixture.remove() }
    try fixture.createPayload()

    let diagnostics = CompanionDiagnostics(
      bundleURL: fixture.bundleURL,
      installation: StubInstallationStatusReader(status: status)
    )

    #expect(try diagnostics.currentState() == expectedState)
  }
}

private struct StubInstallationStatusReader: InstallationStatusReading {
  let status: InstallationStatus

  func currentStatus() throws -> InstallationStatus {
    status
  }
}

private struct CompanionBundleFixture {
  let bundleURL: URL

  init() throws {
    bundleURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
      .appendingPathComponent("Clamshell.app", isDirectory: true)
    try FileManager.default.createDirectory(
      at: bundleURL,
      withIntermediateDirectories: true
    )
  }

  func createCLI() throws {
    try createFile(at: bundleURL.appendingPathComponent("Contents/MacOS/clamshellctl"))
  }

  func createPayload() throws {
    try createCLI()
    try createFile(at: bundleURL.appendingPathComponent("Contents/Resources/clamshellctl-helper"))
  }

  func remove() {
    try? FileManager.default.removeItem(at: bundleURL)
  }

  private func createFile(at url: URL) throws {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    FileManager.default.createFile(atPath: url.path, contents: Data())
  }
}
