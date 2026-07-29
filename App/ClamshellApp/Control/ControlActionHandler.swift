import ClamshellControlModel
import ClamshellControlProtocol
import Foundation
import OSLog
import WidgetKit

struct ControlActionHandler: Sendable {
  enum Outcome: Equatable, Sendable {
    case applied
    case failed
    case ignored
  }

  static let live = Self(
    model: .live,
    reloadControls: { ControlCenter.shared.reloadAllControls() }
  )

  private static let logger = Logger(
    subsystem: "uk.co.lmliam.clamshell",
    category: "ControlAction"
  )

  private let model: ControlModel
  private let reloadControls: @Sendable () -> Void

  init(
    model: ControlModel,
    reloadControls: @escaping @Sendable () -> Void
  ) {
    self.model = model
    self.reloadControls = reloadControls
  }

  func handle(_ url: URL) -> Outcome {
    guard let request = ControlActionRequest(url: url) else {
      Self.logger.error("Ignored an invalid control action URL")
      return .ignored
    }

    defer { reloadControls() }

    do {
      try model.setValue(request.isEnabled)
      return .applied
    } catch {
      Self.logger.error("Could not apply the control action: \(error.localizedDescription)")
      return .failed
    }
  }
}
