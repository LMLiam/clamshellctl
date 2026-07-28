import ArgumentParser
import ClamshellCore

@main
struct ClamshellCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "clamshellctl",
        abstract: "Control battery clamshell mode on macOS.",
        version: BuildVersion.current,
        subcommands: [
            StatusCommand.self,
            EnableCommand.self,
            DisableCommand.self,
            ToggleCommand.self,
            SetupCommand.self,
            UninstallCommand.self,
        ],
        defaultSubcommand: StatusCommand.self
    )
}
