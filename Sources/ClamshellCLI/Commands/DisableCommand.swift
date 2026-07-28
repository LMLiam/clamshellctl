import ArgumentParser

struct DisableCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "disable",
        abstract: "Prevent clamshell mode while using battery power."
    )

    @OptionGroup var output: OutputOptions

    func run() throws {
        let result = try CommandComposition.clamshellService().set(.disabled)
        Console(isQuiet: output.quiet).writeTransition(result)
    }
}
