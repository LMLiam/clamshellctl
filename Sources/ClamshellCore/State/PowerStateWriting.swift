public protocol PowerStateWriting: Sendable {
  func setState(_ state: ClamshellState) throws
}
