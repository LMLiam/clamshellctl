public struct PrivilegedHelperClient: PowerStateWriting, Sendable {
    public static let setupCommand = #"sudo "$(brew --prefix)/bin/clamshellctl" setup"#

    private static let executable = "/usr/bin/sudo"
    private let runner: any ProcessRunning

    public init(runner: any ProcessRunning) {
        self.runner = runner
    }

    public func setState(_ state: ClamshellState) throws {
        let action = state == .enabled ? "enable" : "disable"
        let result = try runner.run(
            Self.executable,
            arguments: ["-n", PrivilegedPaths.helper, action]
        )

        guard result.terminationStatus == 0 else {
            throw ClamshellError.privilegedHelperUnavailable(
                setupCommand: Self.setupCommand
            )
        }
    }
}
