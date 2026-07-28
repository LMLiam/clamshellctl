public struct ClamshellService: Sendable {
  private let stateReader: any PowerStateReading
  private let stateWriter: any PowerStateWriting

  public init(
    stateReader: any PowerStateReading,
    stateWriter: any PowerStateWriting
  ) {
    self.stateReader = stateReader
    self.stateWriter = stateWriter
  }

  public func set(_ requested: ClamshellState) throws -> TransitionResult {
    let current = try stateReader.currentState()
    return try set(requested, from: current)
  }

  public func toggle() throws -> TransitionResult {
    let current = try stateReader.currentState()
    let requested: ClamshellState = current == .enabled ? .disabled : .enabled
    return try set(requested, from: current)
  }

  private func set(
    _ requested: ClamshellState,
    from previous: ClamshellState
  ) throws -> TransitionResult {
    guard previous != requested else {
      return TransitionResult(
        previous: previous,
        current: previous,
        didChange: false
      )
    }

    try stateWriter.setState(requested)
    let current = try stateReader.currentState()
    guard current == requested else {
      throw ClamshellError.stateVerificationFailed(
        expected: requested,
        actual: current
      )
    }

    return TransitionResult(
      previous: previous,
      current: current,
      didChange: true
    )
  }
}
