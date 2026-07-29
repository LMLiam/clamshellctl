import ClamshellCore
import Foundation

struct AppleScriptAdministratorAuthorizer: AdministratorAuthorizing {
  private static let applicationPath = "/Applications/Clamshell.app"
  private static let osascriptPath = "/usr/bin/osascript"

  private let bundleURL: URL
  private let accountName: String
  private let runner: any ProcessRunning

  init(
    bundleURL: URL,
    accountName: String = NSUserName(),
    runner: any ProcessRunning = FoundationProcessRunner()
  ) {
    self.bundleURL = bundleURL
    self.accountName = accountName
    self.runner = runner
  }

  func run(_ request: AdministratorRequest) async throws {
    guard bundleURL.standardizedFileURL.path == Self.applicationPath else {
      throw AdministratorAuthorizationError.invalidApplicationLocation
    }

    let runner = runner
    let script = try administratorScript(for: request)
    let result = try await Task.detached {
      try runner.run(Self.osascriptPath, arguments: ["-e", script])
    }.value

    guard result.terminationStatus == 0 else {
      throw ClamshellError.processFailed(
        executable: Self.osascriptPath,
        terminationStatus: result.terminationStatus,
        standardError: result.standardError
      )
    }
  }

  private func administratorScript(for request: AdministratorRequest) throws -> String {
    let account = try SudoersPolicy(username: accountName).username
    let executable = "\(Self.applicationPath)/Contents/MacOS/clamshellctl"
    let command = (["/usr/bin/env", "SUDO_USER=\(account)", executable] + arguments(for: request))
      .map(shellQuote)
      .joined(separator: " ")
    return "do shell script \"\(appleScriptEscape(command))\" with administrator privileges"
  }

  private func arguments(for request: AdministratorRequest) -> [String] {
    switch request {
    case let .install(exposeCommand):
      ["setup"] + (exposeCommand ? ["--expose-command"] : []) + ["--quiet"]
    case let .uninstall(removeCommand):
      ["uninstall"] + (removeCommand ? ["--remove-command"] : []) + ["--quiet"]
    }
  }

  private func shellQuote(_ value: String) -> String {
    "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
  }

  private func appleScriptEscape(_ value: String) -> String {
    value
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
  }
}
