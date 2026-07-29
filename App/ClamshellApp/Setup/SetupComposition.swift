import ClamshellCore
import Foundation

@MainActor
enum SetupComposition {
  static func makeModel(bundle: Bundle = .main) -> SetupModel {
    let bundleURL = bundle.bundleURL
    let executablePath =
      bundleURL
      .appendingPathComponent("Contents/MacOS/clamshellctl")
      .path

    return SetupModel(
      diagnostics: CompanionDiagnostics(
        bundleURL: bundleURL,
        installation: PrivilegedInstallation(executablePath: executablePath)
      ),
      authorizer: AppleScriptAdministratorAuthorizer(bundleURL: bundleURL)
    )
  }
}
