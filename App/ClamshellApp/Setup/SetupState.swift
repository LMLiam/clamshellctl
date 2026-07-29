enum SetupState: Sendable, Equatable {
  case needsSetup
  case ready
  case invalidHelper
  case missingBundlePayload(commandAvailable: Bool)

  var allowsSetup: Bool {
    switch self {
    case .needsSetup, .invalidHelper:
      true
    case .ready, .missingBundlePayload:
      false
    }
  }

  var allowsPrivilegedRemoval: Bool {
    switch self {
    case .ready, .invalidHelper, .missingBundlePayload(commandAvailable: true):
      true
    case .needsSetup, .missingBundlePayload(commandAvailable: false):
      false
    }
  }
}
