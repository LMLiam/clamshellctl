import Foundation

public enum ControlActionRequest: Equatable, Sendable {
  case enableBatteryClamshellMode
  case disableBatteryClamshellMode

  public init?(url: URL) {
    switch url.absoluteString {
    case Self.enableURL.absoluteString:
      self = .enableBatteryClamshellMode
    case Self.disableURL.absoluteString:
      self = .disableBatteryClamshellMode
    default:
      return nil
    }
  }

  public var isEnabled: Bool {
    self == .enableBatteryClamshellMode
  }

  public var url: URL {
    switch self {
    case .enableBatteryClamshellMode:
      Self.enableURL
    case .disableBatteryClamshellMode:
      Self.disableURL
    }
  }

  private static let enableURL = makeURL(path: "/enable")
  private static let disableURL = makeURL(path: "/disable")

  private static func makeURL(path: String) -> URL {
    var components = URLComponents()
    components.scheme = "clamshellctl"
    components.host = "battery-clamshell"
    components.path = path

    guard let url = components.url else {
      preconditionFailure("The static control action URL is invalid")
    }
    return url
  }
}
