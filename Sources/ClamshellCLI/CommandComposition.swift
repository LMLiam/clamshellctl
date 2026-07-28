import ClamshellCore
import Foundation

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
