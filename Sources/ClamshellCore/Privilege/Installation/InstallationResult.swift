public struct InstallationResult: Sendable, Equatable {
  public let helperPath: String
  public let sudoersPolicyPath: String
  public let didChange: Bool

  public init(
    helperPath: String,
    sudoersPolicyPath: String,
    didChange: Bool = true
  ) {
    self.helperPath = helperPath
    self.sudoersPolicyPath = sudoersPolicyPath
    self.didChange = didChange
  }
}
