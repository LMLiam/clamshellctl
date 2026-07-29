enum ApplicationRuntimePolicy {
  static func shouldStartApplication(environment: [String: String]) -> Bool {
    environment["XCTestConfigurationFilePath"] == nil
  }
}
