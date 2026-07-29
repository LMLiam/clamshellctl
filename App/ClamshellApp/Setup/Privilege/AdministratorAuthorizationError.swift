import Foundation

enum AdministratorAuthorizationError: Error, Equatable, LocalizedError {
  case invalidApplicationLocation

  var errorDescription: String? {
    switch self {
    case .invalidApplicationLocation:
      "Move Clamshell to the Applications folder before you continue."
    }
  }
}
