import Testing

@testable import ClamshellCore

@Suite("Privileged installation failures")
struct PrivilegedInstallationFailureTests {
  @Test("rejects installation when the helper payload is missing")
  func missingHelperPayload() {
    let log = InstallationOperationLog()
    let installation = PrivilegedInstallation(
      fileSystem: RecordingInstallationFileSystem(files: [:], log: log),
      runner: InstallationRecordingRunner(result: .success, log: log),
      effectiveUserID: 0,
      environment: ["SUDO_USER": "liam"],
      executablePath: "/tmp/build/clamshellctl",
      temporarySuffix: "test"
    )

    #expect(throws: ClamshellError.helperPayloadNotFound) {
      try installation.install()
    }
  }

  @Test("rejects an installation that does not verify")
  func verificationFailure() {
    let log = InstallationOperationLog()
    let source = "/tmp/build/clamshellctl-helper"
    let fileSystem = RecordingInstallationFileSystem(
      files: [source: "helper payload"],
      log: log,
      reportsMatchingContents: false
    )
    let installation = PrivilegedInstallation(
      fileSystem: fileSystem,
      runner: InstallationRecordingRunner(result: .success, log: log),
      effectiveUserID: 0,
      environment: ["SUDO_USER": "liam"],
      executablePath: "/tmp/build/clamshellctl",
      temporarySuffix: "test"
    )

    #expect(throws: ClamshellError.installationVerificationFailed) {
      try installation.install()
    }
  }
}
