public protocol PowerStateReading: Sendable {
    func currentState() throws -> ClamshellState
}
