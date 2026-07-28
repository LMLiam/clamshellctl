import Darwin
import Foundation

public struct PrivilegedInstallation: Sendable {
  private let fileSystem: any InstallationFileSystem
  private let runner: any ProcessRunning
  private let effectiveUserID: UInt32
  private let environment: [String: String]
  private let executablePath: String
  private let temporarySuffix: String

  public init(
    fileSystem: any InstallationFileSystem,
    runner: any ProcessRunning,
    effectiveUserID: UInt32,
    environment: [String: String],
    executablePath: String,
    temporarySuffix: String = UUID().uuidString
  ) {
    self.fileSystem = fileSystem
    self.runner = runner
    self.effectiveUserID = effectiveUserID
    self.environment = environment
    self.executablePath = executablePath
    self.temporarySuffix = temporarySuffix
  }

  public init(executablePath: String) {
    self.init(
      fileSystem: FoundationInstallationFileSystem(),
      runner: FoundationProcessRunner(),
      effectiveUserID: geteuid(),
      environment: ProcessInfo.processInfo.environment,
      executablePath: executablePath
    )
  }

  /// Stages, validates, and verifies root-owned files, skipping an identical installation.
  public func install() throws -> InstallationResult {
    try requireAdministratorPrivileges()

    guard let originalUser = environment["SUDO_USER"], !originalUser.isEmpty else {
      throw ClamshellError.originalUserUnavailable
    }
    let policy = try SudoersPolicy(username: originalUser)
    let payload = try helperPayloadPath()

    if try isConfigured(payload: payload, policy: policy) {
      return InstallationResult(
        helperPath: PrivilegedPaths.helper,
        sudoersPolicyPath: PrivilegedPaths.sudoersPolicy,
        didChange: false
      )
    }

    try installHelper(payload: payload)
    try installPolicy(policy)

    guard try isConfigured(payload: payload, policy: policy) else {
      throw ClamshellError.installationVerificationFailed
    }

    return InstallationResult(
      helperPath: PrivilegedPaths.helper,
      sudoersPolicyPath: PrivilegedPaths.sudoersPolicy,
      didChange: true
    )
  }

  /// Removes only the two managed installation paths and is safe to repeat.
  public func uninstall() throws -> UninstallationResult {
    try requireAdministratorPrivileges(command: PrivilegedHelperClient.uninstallCommand)

    var removedPaths: [String] = []
    for path in [PrivilegedPaths.helper, PrivilegedPaths.sudoersPolicy]
    where fileSystem.itemExists(at: path) {
      try fileSystem.removeItem(at: path)
      removedPaths.append(path)
    }
    return UninstallationResult(removedPaths: removedPaths)
  }

  private func requireAdministratorPrivileges() throws {
    try requireAdministratorPrivileges(command: PrivilegedHelperClient.setupCommand)
  }

  private func installHelper(payload: String) throws {
    let temporary = temporaryPath(for: PrivilegedPaths.helper)
    var temporaryExists = false
    defer {
      if temporaryExists {
        try? fileSystem.removeItem(at: temporary)
      }
    }

    try fileSystem.copyItem(at: payload, to: temporary)
    temporaryExists = true
    try fileSystem.setOwner(userID: 0, groupID: 0, at: temporary)
    try fileSystem.setPermissions(0o755, at: temporary)
    try fileSystem.replaceItem(at: PrivilegedPaths.helper, withItemAt: temporary)
    temporaryExists = false
  }

  private func installPolicy(_ policy: SudoersPolicy) throws {
    let temporary = temporaryPath(for: PrivilegedPaths.sudoersPolicy)
    var temporaryExists = false
    defer {
      if temporaryExists {
        try? fileSystem.removeItem(at: temporary)
      }
    }

    try fileSystem.write(policy.contents, to: temporary)
    temporaryExists = true
    try fileSystem.setOwner(userID: 0, groupID: 0, at: temporary)
    try fileSystem.setPermissions(0o440, at: temporary)

    let validation = try runner.run("/usr/sbin/visudo", arguments: ["-cf", temporary])
    guard validation.terminationStatus == 0 else {
      throw ClamshellError.sudoersValidationFailed
    }

    try fileSystem.replaceItem(at: PrivilegedPaths.sudoersPolicy, withItemAt: temporary)
    temporaryExists = false
  }

  private func requireAdministratorPrivileges(command: String) throws {
    guard effectiveUserID == 0 else {
      throw ClamshellError.administratorPrivilegesRequired(
        command: command
      )
    }
  }

  private func helperPayloadPath() throws -> String {
    let executable = URL(fileURLWithPath: executablePath).standardizedFileURL
    let executableDirectory = executable.deletingLastPathComponent()
    var candidates = [
      executableDirectory.appendingPathComponent("clamshellctl-helper").path
    ]

    if executableDirectory.lastPathComponent == "bin" {
      candidates.append(
        executableDirectory
          .deletingLastPathComponent()
          .appendingPathComponent("libexec/clamshellctl-helper")
          .path
      )
    }

    guard let payload = candidates.first(where: fileSystem.isRegularFile(at:)) else {
      throw ClamshellError.helperPayloadNotFound
    }
    return payload
  }

  private func temporaryPath(for destination: String) -> String {
    "\(destination).installing.\(temporarySuffix)"
  }

  private func isConfigured(payload: String, policy: SudoersPolicy) throws -> Bool {
    guard
      fileSystem.isRegularFile(at: PrivilegedPaths.helper),
      fileSystem.contentsEqual(at: payload, and: PrivilegedPaths.helper),
      try fileSystem.attributes(at: PrivilegedPaths.helper)
        == InstalledFileAttributes(userID: 0, groupID: 0, permissions: 0o755),
      fileSystem.isRegularFile(at: PrivilegedPaths.sudoersPolicy),
      try fileSystem.readText(at: PrivilegedPaths.sudoersPolicy) == policy.contents,
      try fileSystem.attributes(at: PrivilegedPaths.sudoersPolicy)
        == InstalledFileAttributes(userID: 0, groupID: 0, permissions: 0o440)
    else {
      return false
    }

    let validation = try runner.run(
      "/usr/sbin/visudo",
      arguments: ["-cf", PrivilegedPaths.sudoersPolicy]
    )
    return validation.terminationStatus == 0
  }
}
