import ClamshellCore

public struct ControlModel: Sendable {
  public static let live: Self = {
    let runner = FoundationProcessRunner()
    return Self(
      stateReader: PowerSettingsClient(runner: runner),
      stateWriter: PrivilegedHelperClient(runner: runner)
    )
  }()

  private let stateReader: any PowerStateReading
  private let service: ClamshellService

  public init(
    stateReader: any PowerStateReading,
    stateWriter: any PowerStateWriting
  ) {
    self.stateReader = stateReader
    service = ClamshellService(
      stateReader: stateReader,
      stateWriter: stateWriter
    )
  }

  public func currentValue() throws -> Bool {
    try stateReader.currentState() == .enabled
  }

  public func setValue(_ isEnabled: Bool) throws {
    let requestedState = isEnabled ? ClamshellState.enabled : .disabled
    _ = try service.set(requestedState)
  }
}
