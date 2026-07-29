import Foundation

protocol CompanionPayloadInspecting: Sendable {
  func isRegularFile(at url: URL) -> Bool
}
