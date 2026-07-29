import ClamshellCore
import Darwin
import Foundation

@main
enum ClamshellHelper {
  static func main() {
    guard geteuid() == 0 else {
      fail("Administrator privileges are required.", exitCode: EX_NOPERM)
    }

    do {
      let mutation = try PowerMutation(
        rawArguments: Array(CommandLine.arguments.dropFirst())
      )
      let powerSettings = PowerSettingsClient(runner: FoundationProcessRunner())
      let service = ClamshellService(
        stateReader: powerSettings,
        stateWriter: powerSettings
      )
      _ = try service.set(mutation.state)
    } catch ClamshellError.invalidHelperArguments {
      fail("Usage: clamshellctl-helper <enable|disable>", exitCode: EX_USAGE)
    } catch {
      fail("Unable to update battery clamshell mode.", exitCode: EX_SOFTWARE)
    }
  }

  private static func fail(_ message: String, exitCode: Int32) -> Never {
    FileHandle.standardError.write(Data("\(message)\n".utf8))
    exit(exitCode)
  }
}
