public struct ProcessResult: Sendable, Equatable {
    public let standardOutput: String
    public let standardError: String
    public let terminationStatus: Int32

    public init(
        standardOutput: String,
        standardError: String,
        terminationStatus: Int32
    ) {
        self.standardOutput = standardOutput
        self.standardError = standardError
        self.terminationStatus = terminationStatus
    }
}
