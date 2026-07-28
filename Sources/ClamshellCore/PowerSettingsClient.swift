public struct PowerSettingsClient: Sendable {
    private let runner: any ProcessRunning
    private let parser: PowerSettingsParser

    public init(
        runner: any ProcessRunning,
        parser: PowerSettingsParser = PowerSettingsParser()
    ) {
        self.runner = runner
        self.parser = parser
    }

    public func currentState() throws -> ClamshellState {
        let executable = "/usr/bin/pmset"
        let result = try runner.run(executable, arguments: ["-g", "custom"])

        guard result.terminationStatus == 0 else {
            throw ClamshellError.processFailed(
                executable: executable,
                terminationStatus: result.terminationStatus,
                standardError: result.standardError
            )
        }

        return try parser.batteryState(from: result.standardOutput)
    }
}
