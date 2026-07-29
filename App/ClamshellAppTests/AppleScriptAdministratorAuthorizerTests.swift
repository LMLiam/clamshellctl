import ClamshellCore
import Foundation
import Testing

@testable import Clamshell

@Suite("Administrator authorizer")
struct AppleScriptAdministratorAuthorizerTests {
  @Test("requests one allowlisted setup command")
  func setup() async throws {
    let runner = RecordingProcessRunner()
    let authorizer = AppleScriptAdministratorAuthorizer(
      bundleURL: URL(fileURLWithPath: "/Applications/Clamshell.app"),
      accountName: "liam",
      runner: runner
    )

    try await authorizer.run(.install(exposeCommand: true))

    #expect(
      runner.invocations == [
        ProcessInvocation(
          executable: "/usr/bin/osascript",
          arguments: [
            "-e",
            "do shell script \"'/usr/bin/env' 'SUDO_USER=liam' '/Applications/Clamshell.app/Contents/MacOS/clamshellctl' 'setup' '--expose-command' '--quiet'\" with administrator privileges",
          ]
        )
      ])
  }

  @Test("requests one allowlisted removal command")
  func removal() async throws {
    let runner = RecordingProcessRunner()
    let authorizer = AppleScriptAdministratorAuthorizer(
      bundleURL: URL(fileURLWithPath: "/Applications/Clamshell.app"),
      accountName: "liam",
      runner: runner
    )

    try await authorizer.run(.uninstall(removeCommand: true))

    #expect(
      runner.invocations.first?.arguments.last
        == "do shell script \"'/usr/bin/env' 'SUDO_USER=liam' '/Applications/Clamshell.app/Contents/MacOS/clamshellctl' 'uninstall' '--remove-command' '--quiet'\" with administrator privileges"
    )
    #expect(runner.invocations.count == 1)
  }

  @Test("rejects a companion outside Applications without starting a process")
  func invalidApplicationLocation() async {
    let runner = RecordingProcessRunner()
    let authorizer = AppleScriptAdministratorAuthorizer(
      bundleURL: URL(fileURLWithPath: "/tmp/Clamshell.app"),
      accountName: "liam",
      runner: runner
    )

    await #expect(throws: AdministratorAuthorizationError.invalidApplicationLocation) {
      try await authorizer.run(.install(exposeCommand: false))
    }
    #expect(runner.invocations.isEmpty)
  }

  @Test(
    "rejects a substituted path without starting a process",
    arguments: ["Clamshell.app", "clamshellctl"]
  )
  func substitutedPath(lastPathComponent: String) async {
    let runner = RecordingProcessRunner()
    let authorizer = AppleScriptAdministratorAuthorizer(
      bundleURL: URL(fileURLWithPath: "/Applications/Clamshell.app"),
      accountName: "liam",
      runner: runner,
      resolvedPath: { url in
        url.lastPathComponent == lastPathComponent ? "/tmp/substitution" : url.path
      }
    )

    await #expect(throws: AdministratorAuthorizationError.invalidApplicationLocation) {
      try await authorizer.run(.install(exposeCommand: false))
    }
    #expect(runner.invocations.isEmpty)
  }

  @Test("rejects an unsafe account name without starting a process")
  func unsafeAccountName() async {
    let runner = RecordingProcessRunner()
    let authorizer = AppleScriptAdministratorAuthorizer(
      bundleURL: URL(fileURLWithPath: "/Applications/Clamshell.app"),
      accountName: "name with spaces",
      runner: runner
    )

    await #expect(throws: ClamshellError.invalidUsername("name with spaces")) {
      try await authorizer.run(.install(exposeCommand: false))
    }
    #expect(runner.invocations.isEmpty)
  }

  @Test("reports an osascript failure")
  func processFailure() async {
    let runner = RecordingProcessRunner(
      result: ProcessResult(
        standardOutput: "",
        standardError: "User cancelled.",
        terminationStatus: 1
      )
    )
    let authorizer = AppleScriptAdministratorAuthorizer(
      bundleURL: URL(fileURLWithPath: "/Applications/Clamshell.app"),
      accountName: "liam",
      runner: runner
    )

    await #expect(
      throws: ClamshellError.processFailed(
        executable: "/usr/bin/osascript",
        terminationStatus: 1,
        standardError: "User cancelled."
      )
    ) {
      try await authorizer.run(.install(exposeCommand: false))
    }
  }
}

private struct ProcessInvocation: Equatable {
  let executable: String
  let arguments: [String]
}

private final class RecordingProcessRunner: ProcessRunning, @unchecked Sendable {
  private let result: ProcessResult
  private(set) var invocations: [ProcessInvocation] = []

  init(
    result: ProcessResult = ProcessResult(
      standardOutput: "",
      standardError: "",
      terminationStatus: 0
    )
  ) {
    self.result = result
  }

  func run(_ executable: String, arguments: [String]) throws -> ProcessResult {
    invocations.append(ProcessInvocation(executable: executable, arguments: arguments))
    return result
  }
}
