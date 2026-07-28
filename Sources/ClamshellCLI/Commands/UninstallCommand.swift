import ArgumentParser

struct UninstallCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "uninstall",
        abstract: "Remove the restricted privileged helper."
    )

    @OptionGroup var output: OutputOptions

    func run() throws {
        let result = try CommandComposition.privilegedInstallation().uninstall()
        let console = Console(isQuiet: output.quiet)

        guard !result.removedPaths.isEmpty else {
            console.writeLine("Privileged setup: already removed")
            return
        }

        console.writeLine("Privileged setup removed:")
        for path in result.removedPaths {
            console.writeLine(path)
        }
    }
}
