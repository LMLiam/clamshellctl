import AppKit
import ClamshellControlProtocol
import Foundation

public struct WorkspaceControlActionRequester: Sendable {
  public typealias OpenURL = @Sendable (URL) async throws -> Void

  public static let live = Self { url in
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = false
    _ = try await NSWorkspace.shared.open(url, configuration: configuration)
  }

  private let openURL: OpenURL

  public init(openURL: @escaping OpenURL) {
    self.openURL = openURL
  }

  public func request(_ request: ControlActionRequest) async throws {
    try await openURL(request.url)
  }
}
