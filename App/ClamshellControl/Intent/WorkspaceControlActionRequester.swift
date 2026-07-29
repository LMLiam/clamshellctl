import AppKit
import ClamshellControlModel
import ClamshellControlProtocol
import Foundation

public struct WorkspaceControlActionRequester: Sendable {
  public typealias OpenURL = @Sendable (URL) async throws -> Void
  public typealias CurrentValue = @Sendable () async throws -> Bool
  public typealias WaitForRetry = @Sendable () async throws -> Void

  public static let live = Self(
    openURL: { url in
      let configuration = NSWorkspace.OpenConfiguration()
      configuration.activates = false
      _ = try await NSWorkspace.shared.open(url, configuration: configuration)
    },
    currentValue: { try ControlModel.live.currentValue() },
    waitForRetry: { try await Task.sleep(for: .milliseconds(100)) }
  )

  private let openURL: OpenURL
  private let currentValue: CurrentValue
  private let waitForRetry: WaitForRetry
  private let maximumAttempts: Int

  public init(
    openURL: @escaping OpenURL,
    currentValue: @escaping CurrentValue,
    waitForRetry: @escaping WaitForRetry,
    maximumAttempts: Int = 50
  ) {
    precondition(maximumAttempts > 0)
    self.openURL = openURL
    self.currentValue = currentValue
    self.waitForRetry = waitForRetry
    self.maximumAttempts = maximumAttempts
  }

  public func request(_ request: ControlActionRequest) async throws {
    try await openURL(request.url)

    for attempt in 1...maximumAttempts {
      if try await currentValue() == request.isEnabled {
        return
      }
      if attempt < maximumAttempts {
        try await waitForRetry()
      }
    }

    throw WorkspaceControlActionError.stateNotConfirmed
  }
}
