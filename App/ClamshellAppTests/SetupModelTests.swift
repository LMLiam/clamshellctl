import Foundation
import Testing

@testable import Clamshell

@MainActor
@Suite("Setup model")
struct SetupModelTests {
  @Test(
    "shows every diagnostic state without requesting administrator access",
    arguments: [
      SetupState.needsSetup,
      .ready,
      .invalidHelper,
      .missingBundlePayload,
    ]
  )
  func diagnosticState(state: SetupState) {
    let diagnostics = RecordingDiagnostics(states: [state])
    let authorizer = RecordingAuthorizer()
    let model = SetupModel(diagnostics: diagnostics, authorizer: authorizer)

    model.refresh()

    #expect(model.state == state)
    #expect(diagnostics.callCount == 1)
    #expect(authorizer.requests.isEmpty)
  }

  @Test("requests setup once and refreshes diagnostics")
  func setup() async {
    let diagnostics = RecordingDiagnostics(states: [.ready])
    let authorizer = RecordingAuthorizer()
    let model = SetupModel(diagnostics: diagnostics, authorizer: authorizer)
    model.exposeCommand = true

    await model.setUp()

    #expect(authorizer.requests == [.install(exposeCommand: true)])
    #expect(diagnostics.callCount == 1)
    #expect(model.state == .ready)
    #expect(model.errorMessage == nil)
  }

  @Test("requests removal once and refreshes diagnostics")
  func removal() async {
    let diagnostics = RecordingDiagnostics(states: [.needsSetup])
    let authorizer = RecordingAuthorizer()
    let model = SetupModel(diagnostics: diagnostics, authorizer: authorizer)

    await model.removePrivilegedSetup()

    #expect(authorizer.requests == [.uninstall(removeCommand: true)])
    #expect(diagnostics.callCount == 1)
    #expect(model.state == .needsSetup)
    #expect(model.errorMessage == nil)
  }

  @Test("reports an authorisation failure without a diagnostic mutation")
  func authorisationFailure() async {
    let diagnostics = RecordingDiagnostics(states: [.ready])
    let authorizer = RecordingAuthorizer(error: SetupTestError.authorisationFailed)
    let model = SetupModel(diagnostics: diagnostics, authorizer: authorizer)

    await model.setUp()

    #expect(authorizer.requests == [.install(exposeCommand: false)])
    #expect(diagnostics.callCount == 0)
    #expect(model.errorMessage == "Authorisation failed")
  }
}

private final class RecordingDiagnostics: CompanionDiagnosing, @unchecked Sendable {
  private(set) var callCount = 0
  private var states: [SetupState]

  init(states: [SetupState]) {
    self.states = states
  }

  func currentState() throws -> SetupState {
    callCount += 1
    return states.removeFirst()
  }
}

private final class RecordingAuthorizer: AdministratorAuthorizing, @unchecked Sendable {
  private(set) var requests: [AdministratorRequest] = []
  private let error: Error?

  init(error: Error? = nil) {
    self.error = error
  }

  func run(_ request: AdministratorRequest) async throws {
    requests.append(request)
    if let error {
      throw error
    }
  }
}

private enum SetupTestError: LocalizedError {
  case authorisationFailed

  var errorDescription: String? {
    "Authorisation failed"
  }
}
