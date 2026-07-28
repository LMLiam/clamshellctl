public struct PowerMutation: Sendable, Equatable {
    public let state: ClamshellState

    public init(rawArguments: [String]) throws {
        switch rawArguments {
        case ["enable"]:
            state = .enabled
        case ["disable"]:
            state = .disabled
        default:
            throw ClamshellError.invalidHelperArguments
        }
    }
}

public struct PowerSettingsClient: PowerStateReading, PowerStateWriting, Sendable {
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
        let result = try runPmset(arguments: ["-g", "custom"])

        return try parser.batteryState(from: result.standardOutput)
    }

    public func setState(_ state: ClamshellState) throws {
        let value = state == .enabled ? "1" : "0"
        _ = try runPmset(arguments: ["-b", "disablesleep", value])
    }

    private func runPmset(arguments: [String]) throws -> ProcessResult {
        let executable = "/usr/bin/pmset"
        let result = try runner.run(executable, arguments: arguments)

        guard result.terminationStatus == 0 else {
            throw ClamshellError.processFailed(
                executable: executable,
                terminationStatus: result.terminationStatus,
                standardError: result.standardError
            )
        }

        return result
    }
}
