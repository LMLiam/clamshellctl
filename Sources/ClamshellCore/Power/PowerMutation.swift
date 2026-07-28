public struct PowerMutation: Sendable, Equatable {
  public let state: ClamshellState

  public init(rawArguments: [String]) throws {
    switch rawArguments {
    case ["enable"]:
      state = .enabled
    case ["disable"]:
      state = .disabled
    default:
      throw ClamshellError.invalidHelperArguments
    }
  }
}
