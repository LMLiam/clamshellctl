import Testing

@testable import ClamshellCore

@Suite("Companion privileged installation")
struct PrivilegedInstallationCompanionTests {
  private let executable = "/Applications/Clamshell.app/Contents/MacOS/clamshellctl"
  private let helperPayload = "/Applications/Clamshell.app/Contents/Resources/clamshellctl-helper"

  @Test("finds the helper payload in the companion resources")
  func companionPayload() throws {
    let log = InstallationOperationLog()
    let fileSystem = RecordingInstallationFileSystem(
      files: [helperPayload: "helper payload"],
      log: log
    )
    let installation = makeInstallation(fileSystem: fileSystem, log: log)

    _ = try installation.install()

    #expect(fileSystem.contents(at: PrivilegedPaths.helper) == "helper payload")
  }

  @Test("reports missing setup without a privileged operation")
  func missingStatus() throws {
    let log = InstallationOperationLog()
    let installation = makeInstallation(
      fileSystem: RecordingInstallationFileSystem(files: [:], log: log),
      log: log,
      effectiveUserID: 501,
      environment: [:]
    )

    #expect(try installation.status() == .notInstalled)
    #expect(!log.operations.contains { $0.isMutation })
  }

  @Test("reports a verified setup without changing it")
  func readyStatus() throws {
    let log = InstallationOperationLog()
    let fileSystem = RecordingInstallationFileSystem(
      files: [helperPayload: "helper payload"],
      log: log
    )
    let installation = makeInstallation(fileSystem: fileSystem, log: log)
    _ = try installation.install()
    let operationCount = log.operations.count

    #expect(try installation.status() == .ready)
    #expect(!log.operations.dropFirst(operationCount).contains { $0.isMutation })
  }

  @Test("reports a stale installed helper as invalid")
  func staleHelperStatus() throws {
    let log = InstallationOperationLog()
    let fileSystem = RecordingInstallationFileSystem(
      files: [helperPayload: "helper payload"],
      log: log
    )
    let installation = makeInstallation(fileSystem: fileSystem, log: log)
    _ = try installation.install()
    fileSystem.replaceContents(at: PrivilegedPaths.helper, with: "stale helper")

    #expect(try installation.status() == .invalid)
  }

  @Test("reports a partial setup as invalid")
  func invalidStatus() throws {
    let log = InstallationOperationLog()
    let installation = makeInstallation(
      fileSystem: RecordingInstallationFileSystem(
        files: [PrivilegedPaths.helper: "helper"],
        log: log
      ),
      log: log,
      effectiveUserID: 501,
      environment: [:]
    )

    #expect(try installation.status() == .invalid)
    #expect(!log.operations.contains { $0.isMutation })
  }

  @Test("exposes only the app-bundled command at the managed path")
  func exposesCommand() throws {
    let log = InstallationOperationLog()
    let fileSystem = RecordingInstallationFileSystem(
      files: [helperPayload: "helper payload"],
      log: log
    )
    let installation = makeInstallation(fileSystem: fileSystem, log: log)

    _ = try installation.install(exposeCommand: true)

    #expect(fileSystem.symbolicLinkDestination(at: PrivilegedPaths.cliLink) == executable)
    #expect(
      log.operations.contains(
        .createSymbolicLink(path: PrivilegedPaths.cliLink, destination: executable)
      )
    )
  }

  @Test("does not replace an unrelated command")
  func commandConflict() {
    let log = InstallationOperationLog()
    let fileSystem = RecordingInstallationFileSystem(
      files: [
        helperPayload: "helper payload",
        PrivilegedPaths.cliLink: "unrelated command",
      ],
      log: log
    )
    let installation = makeInstallation(fileSystem: fileSystem, log: log)

    #expect(throws: ClamshellError.cliLinkConflict) {
      try installation.install(exposeCommand: true)
    }
    #expect(fileSystem.contents(at: PrivilegedPaths.cliLink) == "unrelated command")
    #expect(!log.operations.contains { $0.isMutation })
  }

  @Test("does not expose a command from outside the companion bundle")
  func rejectsExternalCommand() {
    let log = InstallationOperationLog()
    let source = "/tmp/build/clamshellctl-helper"
    let installation = PrivilegedInstallation(
      fileSystem: RecordingInstallationFileSystem(
        files: [source: "helper payload"],
        log: log
      ),
      runner: InstallationRecordingRunner(result: .success, log: log),
      effectiveUserID: 0,
      environment: ["SUDO_USER": "liam"],
      executablePath: "/tmp/build/clamshellctl",
      temporarySuffix: "test"
    )

    #expect(throws: ClamshellError.companionExecutableRequired) {
      try installation.install(exposeCommand: true)
    }
    #expect(!log.operations.contains { $0.isMutation })
  }

  @Test("removes the command only when it targets this companion")
  func removesManagedCommand() throws {
    let log = InstallationOperationLog()
    let fileSystem = RecordingInstallationFileSystem(
      files: [:],
      symbolicLinks: [PrivilegedPaths.cliLink: executable],
      log: log
    )
    let installation = makeInstallation(fileSystem: fileSystem, log: log)

    let result = try installation.uninstall(removeCommand: true)

    #expect(result.removedPaths == [PrivilegedPaths.cliLink])
    #expect(fileSystem.symbolicLinkDestination(at: PrivilegedPaths.cliLink) == nil)
  }

  @Test("preserves a command that targets another executable")
  func preservesUnrelatedCommand() throws {
    let log = InstallationOperationLog()
    let fileSystem = RecordingInstallationFileSystem(
      files: [:],
      symbolicLinks: [PrivilegedPaths.cliLink: "/tmp/not-clamshellctl"],
      log: log
    )
    let installation = makeInstallation(fileSystem: fileSystem, log: log)

    _ = try installation.uninstall(removeCommand: true)

    #expect(
      fileSystem.symbolicLinkDestination(at: PrivilegedPaths.cliLink)
        == "/tmp/not-clamshellctl"
    )
  }

  private func makeInstallation(
    fileSystem: RecordingInstallationFileSystem,
    log: InstallationOperationLog,
    effectiveUserID: UInt32 = 0,
    environment: [String: String] = ["SUDO_USER": "liam"]
  ) -> PrivilegedInstallation {
    PrivilegedInstallation(
      fileSystem: fileSystem,
      runner: InstallationRecordingRunner(result: .success, log: log),
      effectiveUserID: effectiveUserID,
      environment: environment,
      executablePath: executable,
      temporarySuffix: "test"
    )
  }
}

private extension InstallationOperation {
  var isMutation: Bool {
    switch self {
    case .copy, .createSymbolicLink, .remove, .replace, .setOwner, .setPermissions, .write:
      true
    default:
      false
    }
  }
}
