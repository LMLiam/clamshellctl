protocol CompanionDiagnosing: Sendable {
  func currentState() throws -> SetupState
}
