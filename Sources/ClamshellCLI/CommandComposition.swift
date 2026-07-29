import ClamshellCore
import Darwin
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
    try PrivilegedInstallation(executablePath: executablePath())
  }

  static func timerController() -> TimerController {
    TimerController(
      paths: TimerPaths(
        homeDirectory: FileManager.default.homeDirectoryForCurrentUser.path
      ),
      userID: getuid()
    )
  }

  static func executablePath() throws -> String {
    guard
      let executablePath = Bundle.main.executableURL?
        .resolvingSymlinksInPath()
        .path
    else {
      throw ClamshellError.executablePathUnavailable
    }
    return executablePath
  }
}
