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

  private static let enableURL = URL(
    string: "clamshellctl://battery-clamshell/enable"
  )!
  private static let disableURL = URL(
    string: "clamshellctl://battery-clamshell/disable"
  )!
}
