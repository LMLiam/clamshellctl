import ClamshellCore
import Foundation

struct AppleScriptAdministratorAuthorizer: AdministratorAuthorizing {
  private static let applicationPath = "/Applications/Clamshell.app"
  private static let executablePath =
    "/Applications/Clamshell.app/Contents/MacOS/clamshellctl"
  private static let osascriptPath = "/usr/bin/osascript"

  typealias ResolvedPath = @Sendable (URL) -> String

  private let bundleURL: URL
  private let accountName: String
  private let runner: any ProcessRunning
  private let resolvedPath: ResolvedPath

  init(
    bundleURL: URL,
    accountName: String = NSUserName(),
    runner: any ProcessRunning = FoundationProcessRunner(),
    resolvedPath: @escaping ResolvedPath = {
      $0.resolvingSymlinksInPath().standardizedFileURL.path
    }
  ) {
    self.bundleURL = bundleURL
    self.accountName = accountName
    self.runner = runner
    self.resolvedPath = resolvedPath
  }

  func run(_ request: AdministratorRequest) async throws {
    let applicationURL = bundleURL.standardizedFileURL
    let executableURL = applicationURL.appendingPathComponent("Contents/MacOS/clamshellctl")
    guard
      applicationURL.path == Self.applicationPath,
      resolvedPath(applicationURL) == Self.applicationPath,
      resolvedPath(executableURL) == Self.executablePath
    else {
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
    let command =
      (["/usr/bin/env", "SUDO_USER=\(account)", Self.executablePath] + arguments(for: request))
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
