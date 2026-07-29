import Foundation

public enum ClamshellError: Error, Equatable, LocalizedError {
  case administratorPrivilegesRequired(command: String)
  case executablePathUnavailable
  case helperPayloadNotFound
  case installationVerificationFailed
  case invalidHelperArguments
  case invalidProcessOutput(executable: String, stream: ProcessOutputStream)
  case invalidDuration(String)
  case invalidTimerExecutablePath(String)
  case invalidUsername(String)
  case originalUserUnavailable
  case privilegedHelperUnavailable(setupCommand: String)
  case processFailed(
    executable: String,
    terminationStatus: Int32,
    standardError: String
  )
  case stateVerificationFailed(expected: ClamshellState, actual: ClamshellState)
  case sudoersValidationFailed
  case timerCalendarConversionFailed
  case timerCleanupFailed(String)
  case timedEnablementRollbackFailed(scheduling: String, rollback: String)
  case unsupportedTimerMetadataVersion(Int)
  case unrecognisedPowerSettings

  public var errorDescription: String? {
    switch self {
    case let .administratorPrivilegesRequired(command):
      "Administrator privileges are required. Run: \(command)"
    case .executablePathUnavailable:
      "Unable to resolve the clamshellctl executable path."
    case .helperPayloadNotFound:
      "Unable to locate the clamshellctl helper payload."
    case .installationVerificationFailed:
      "The privileged installation could not be verified."
    case .invalidHelperArguments:
      "Invalid privileged helper arguments."
    case let .invalidProcessOutput(executable, stream):
      "Unable to decode \(stream.rawValue) from \(executable)."
    case let .invalidDuration(value):
      "Duration '\(value)' is invalid. Use whole minutes (m), hours (h), or days (d), up to 30d."
    case let .invalidTimerExecutablePath(path):
      "The timer executable path is not absolute: \(path)"
    case .invalidUsername:
      "The original account name is unavailable or unsafe."
    case .originalUserUnavailable:
      "Unable to identify the account that requested setup."
    case let .privilegedHelperUnavailable(setupCommand):
      "Privileged helper unavailable. Run: \(setupCommand)"
    case let .processFailed(executable, terminationStatus, standardError):
      processFailureDescription(
        executable: executable,
        terminationStatus: terminationStatus,
        standardError: standardError
      )
    case let .stateVerificationFailed(expected, actual):
      "Battery clamshell mode verification failed: expected \(expected.rawValue), found \(actual.rawValue)."
    case .sudoersValidationFailed:
      "The generated sudoers policy failed validation."
    case .timerCalendarConversionFailed:
      "The timer deadline cannot be converted to calendar components."
    case let .timerCleanupFailed(path):
      "The timer file could not be removed: \(path)"
    case let .timedEnablementRollbackFailed(scheduling, rollback):
      "Timer setup failed: \(scheduling) Rollback failed: \(rollback)"
    case let .unsupportedTimerMetadataVersion(version):
      "Timer metadata schema version \(version) is not supported."
    case .unrecognisedPowerSettings:
      "Unable to read the Battery Power section from pmset."
    }
  }

  private func processFailureDescription(
    executable: String,
    terminationStatus: Int32,
    standardError: String
  ) -> String {
    let detail = standardError.trimmingCharacters(in: .whitespacesAndNewlines)
    let prefix = "\(executable) exited with status \(terminationStatus)."
    return detail.isEmpty ? prefix : "\(prefix) \(detail)"
  }
}
