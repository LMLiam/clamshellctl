import Foundation

public enum ClamshellError: Error, Equatable, LocalizedError {
    case administratorPrivilegesRequired(command: String)
    case helperPayloadNotFound
    case invalidHelperArguments
    case invalidProcessOutput(executable: String, stream: ProcessOutputStream)
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
    case unrecognisedPowerSettings

    public var errorDescription: String? {
        switch self {
        case .administratorPrivilegesRequired(let command):
            "Administrator privileges are required. Run: \(command)"
        case .helperPayloadNotFound:
            "Unable to locate the clamshellctl helper payload."
        case .invalidHelperArguments:
            "Invalid privileged helper arguments."
        case .invalidProcessOutput(let executable, let stream):
            "Unable to decode \(stream.rawValue) from \(executable)."
        case .invalidUsername:
            "The original account name is unavailable or unsafe."
        case .originalUserUnavailable:
            "Unable to identify the account that requested setup."
        case .privilegedHelperUnavailable(let setupCommand):
            "Privileged helper unavailable. Run: \(setupCommand)"
        case .processFailed(let executable, let terminationStatus, let standardError):
            processFailureDescription(
                executable: executable,
                terminationStatus: terminationStatus,
                standardError: standardError
            )
        case .stateVerificationFailed(let expected, let actual):
            "Battery clamshell mode verification failed: expected \(expected.rawValue), found \(actual.rawValue)."
        case .sudoersValidationFailed:
            "The generated sudoers policy failed validation."
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
