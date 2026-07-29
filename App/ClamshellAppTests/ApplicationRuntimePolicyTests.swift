import Testing

@testable import Clamshell

@Suite("Application runtime policy")
struct ApplicationRuntimePolicyTests {
  @Test("skips application coordination in an Xcode test host")
  func testHost() {
    let environment = ["XCTestConfigurationFilePath": "/tmp/Clamshell.xctestconfiguration"]

    #expect(!ApplicationRuntimePolicy.shouldStartApplication(environment: environment))
  }

  @Test("starts the application outside a test host")
  func application() {
    #expect(ApplicationRuntimePolicy.shouldStartApplication(environment: [:]))
  }
}
