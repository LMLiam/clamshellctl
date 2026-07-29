import ClamshellCore

protocol InstallationStatusReading: Sendable {
  func currentStatus() throws -> InstallationStatus
}

extension PrivilegedInstallation: InstallationStatusReading {
  func currentStatus() throws -> InstallationStatus {
    try status()
  }
}
