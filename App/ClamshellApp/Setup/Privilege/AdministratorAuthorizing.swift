protocol AdministratorAuthorizing: Sendable {
  func run(_ request: AdministratorRequest) async throws
}
