import ClamshellCore
import Foundation

struct CompanionDiagnostics: CompanionDiagnosing {
  private let bundleURL: URL
  private let payloadInspector: any CompanionPayloadInspecting
  private let installation: any InstallationStatusReading

  init(
    bundleURL: URL,
    payloadInspector: any CompanionPayloadInspecting = FoundationCompanionPayloadInspector(),
    installation: any InstallationStatusReading
  ) {
    self.bundleURL = bundleURL
    self.payloadInspector = payloadInspector
    self.installation = installation
  }

  func currentState() throws -> SetupState {
    let commandAvailable = payloadInspector.isRegularFile(at: commandURL)
    guard commandAvailable else {
      return .missingBundlePayload(commandAvailable: false)
    }
    guard payloadInspector.isRegularFile(at: helperPayloadURL) else {
      return .missingBundlePayload(commandAvailable: true)
    }

    return switch try installation.currentStatus() {
    case .notInstalled:
      .needsSetup
    case .ready:
      .ready
    case .invalid:
      .invalidHelper
    }
  }

  private var commandURL: URL {
    bundleURL.appendingPathComponent("Contents/MacOS/clamshellctl")
  }

  private var helperPayloadURL: URL {
    bundleURL.appendingPathComponent("Contents/Resources/clamshellctl-helper")
  }
}
