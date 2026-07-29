enum AdministratorRequest: Sendable, Equatable {
  case install(exposeCommand: Bool)
  case uninstall(removeCommand: Bool)
}
