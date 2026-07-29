enum SetupState: Sendable, Equatable {
  case needsSetup
  case ready
  case invalidHelper
  case missingBundlePayload
}
