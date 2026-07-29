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
    guard hasRequiredPayload else {
      return .missingBundlePayload
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

  private var hasRequiredPayload: Bool {
    requiredPayloadURLs.allSatisfy(payloadInspector.isRegularFile)
  }

  private var requiredPayloadURLs: [URL] {
    [
      bundleURL.appendingPathComponent("Contents/MacOS/clamshellctl"),
      bundleURL.appendingPathComponent("Contents/Resources/clamshellctl-helper"),
    ]
  }
}
