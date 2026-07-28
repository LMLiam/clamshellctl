public protocol ProcessRunning: Sendable {
  func run(_ executable: String, arguments: [String]) throws -> ProcessResult
}
