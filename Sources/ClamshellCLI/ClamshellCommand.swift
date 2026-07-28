import ArgumentParser
import ClamshellCore
import Foundation

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

enum CommandComposition {
    static func clamshellService() -> ClamshellService {
        let runner = FoundationProcessRunner()
        return ClamshellService(
            stateReader: PowerSettingsClient(runner: runner),
            stateWriter: PrivilegedHelperClient(runner: runner)
        )
    }

    static func privilegedInstallation() throws -> PrivilegedInstallation {
        guard
            let executablePath = Bundle.main.executableURL?
                .resolvingSymlinksInPath()
                .path
        else {
            throw ClamshellError.executablePathUnavailable
        }
        return PrivilegedInstallation(executablePath: executablePath)
    }
}
