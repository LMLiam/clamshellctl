public enum ClamshellError: Error, Equatable {
    case invalidProcessOutput(executable: String, stream: ProcessOutputStream)
    case processFailed(
        executable: String,
        terminationStatus: Int32,
        standardError: String
    )
    case stateVerificationFailed(expected: ClamshellState, actual: ClamshellState)
    case unrecognisedPowerSettings
}
