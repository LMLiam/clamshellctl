import ArgumentParser

struct SetupCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "setup",
        abstract: "Install the restricted privileged helper."
    )

    @OptionGroup var output: OutputOptions

    func run() throws {
        let result = try CommandComposition.privilegedInstallation().install()
        let console = Console(isQuiet: output.quiet)

        if result.didChange {
            console.writeLine("Privileged setup installed:")
            console.writeLine(result.helperPath)
            console.writeLine(result.sudoersPolicyPath)
        } else {
            console.writeLine("Privileged setup: already configured")
        }
    }
}
