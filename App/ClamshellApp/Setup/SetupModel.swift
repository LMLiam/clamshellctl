import Foundation
import Observation

@MainActor
@Observable
final class SetupModel {
  var exposeCommand = false
  private(set) var errorMessage: String?
  private(set) var isWorking = false
  private(set) var state: SetupState = .needsSetup

  private let diagnostics: any CompanionDiagnosing
  private let authorizer: any AdministratorAuthorizing

  init(
    diagnostics: any CompanionDiagnosing,
    authorizer: any AdministratorAuthorizing
  ) {
    self.diagnostics = diagnostics
    self.authorizer = authorizer
  }

  func refresh() {
    do {
      state = try diagnostics.currentState()
      errorMessage = nil
    } catch {
      state = .invalidHelper
      errorMessage = error.localizedDescription
    }
  }

  func setUp() async {
    await perform(.install(exposeCommand: exposeCommand))
  }

  func installTerminalCommand() async {
    await perform(.install(exposeCommand: true))
  }

  func removePrivilegedSetup() async {
    await perform(.uninstall(removeCommand: true))
  }

  private func perform(_ request: AdministratorRequest) async {
    guard !isWorking else {
      return
    }

    isWorking = true
    defer { isWorking = false }

    do {
      try await authorizer.run(request)
      refresh()
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}
