public struct TransitionResult: Sendable, Equatable {
    public let previous: ClamshellState
    public let current: ClamshellState
    public let didChange: Bool

    public init(previous: ClamshellState, current: ClamshellState, didChange: Bool) {
        self.previous = previous
        self.current = current
        self.didChange = didChange
    }
}
