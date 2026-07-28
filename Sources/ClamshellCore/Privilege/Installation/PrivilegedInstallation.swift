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

    let helperTemporary = temporaryPath(for: PrivilegedPaths.helper)
    var helperTemporaryExists = false
    defer {
      if helperTemporaryExists {
        try? fileSystem.removeItem(at: helperTemporary)
      }
    }

    try fileSystem.copyItem(at: payload, to: helperTemporary)
    helperTemporaryExists = true
    try fileSystem.setOwner(userID: 0, groupID: 0, at: helperTemporary)
    try fileSystem.setPermissions(0o755, at: helperTemporary)
    try fileSystem.replaceItem(
      at: PrivilegedPaths.helper,
      withItemAt: helperTemporary
    )
    helperTemporaryExists = false

    let policyTemporary = temporaryPath(for: PrivilegedPaths.sudoersPolicy)
    var policyTemporaryExists = false
    defer {
      if policyTemporaryExists {
        try? fileSystem.removeItem(at: policyTemporary)
      }
    }

    try fileSystem.write(policy.contents, to: policyTemporary)
    policyTemporaryExists = true
    try fileSystem.setOwner(userID: 0, groupID: 0, at: policyTemporary)
    try fileSystem.setPermissions(0o440, at: policyTemporary)

    let validation = try runner.run(
      "/usr/sbin/visudo",
      arguments: ["-cf", policyTemporary]
    )
    guard validation.terminationStatus == 0 else {
      throw ClamshellError.sudoersValidationFailed
    }

    try fileSystem.replaceItem(
      at: PrivilegedPaths.sudoersPolicy,
      withItemAt: policyTemporary
    )
    policyTemporaryExists = false

    guard try isConfigured(payload: payload, policy: policy) else {
      throw ClamshellError.installationVerificationFailed
    }

    return InstallationResult(
      helperPath: PrivilegedPaths.helper,
      sudoersPolicyPath: PrivilegedPaths.sudoersPolicy,
      didChange: true
    )
  }

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
