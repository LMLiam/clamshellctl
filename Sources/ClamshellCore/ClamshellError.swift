import Foundation

public enum ClamshellError: Error, Equatable, LocalizedError {
    case invalidHelperArguments
    case invalidProcessOutput(executable: String, stream: ProcessOutputStream)
    case privilegedHelperUnavailable(setupCommand: String)
    case processFailed(
        executable: String,
        terminationStatus: Int32,
        standardError: String
    )
    case stateVerificationFailed(expected: ClamshellState, actual: ClamshellState)
    case unrecognisedPowerSettings

    public var errorDescription: String? {
        switch self {
        case .invalidHelperArguments:
            "Invalid privileged helper arguments."
        case .invalidProcessOutput(let executable, let stream):
            "Unable to decode \(stream.rawValue) from \(executable)."
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
