import ClamshellControlModel
import ClamshellControlProtocol
import ClamshellCore
import Foundation
import Synchronization
import Testing

@testable import Clamshell

@Suite("Control action handler")
struct ControlActionHandlerTests {
  @Test("applies a valid request and reloads the control")
  func validRequest() throws {
    let power = RecordingPower(states: [.disabled, .enabled])
    let reloads = ReloadRecorder()
    let handler = ControlActionHandler(
      model: ControlModel(stateReader: power, stateWriter: power),
      reloadControls: reloads.record
    )

    let outcome = handler.handle(
      try #require(URL(string: "clamshellctl://battery-clamshell/enable")))

    #expect(outcome == .applied)
    #expect(power.requestedStates == [.enabled])
    #expect(reloads.count == 1)
  }

  @Test("ignores an invalid request without changing or reloading the control")
  func invalidRequest() throws {
    let power = RecordingPower(states: [.disabled])
    let reloads = ReloadRecorder()
    let handler = ControlActionHandler(
      model: ControlModel(stateReader: power, stateWriter: power),
      reloadControls: reloads.record
    )

    let outcome = handler.handle(
      try #require(URL(string: "clamshellctl://battery-clamshell/enable?unexpected=true")))

    #expect(outcome == .ignored)
    #expect(power.requestedStates.isEmpty)
    #expect(reloads.count == 0)
  }

  @Test("reports a helper failure and reloads the real state")
  func helperFailure() throws {
    let power = RecordingPower(states: [.disabled], writeError: .helperFailed)
    let reloads = ReloadRecorder()
    let handler = ControlActionHandler(
      model: ControlModel(stateReader: power, stateWriter: power),
      reloadControls: reloads.record
    )

    let outcome = handler.handle(
      try #require(URL(string: "clamshellctl://battery-clamshell/enable")))

    #expect(outcome == .failed)
    #expect(power.requestedStates == [.enabled])
    #expect(reloads.count == 1)
  }
}

private enum ControlActionTestError: Error {
  case helperFailed
  case unexpectedRead
}

private final class RecordingPower: PowerStateReading, PowerStateWriting, Sendable {
  private struct State: Sendable {
    var states: [ClamshellState]
    var requestedStates: [ClamshellState] = []
  }

  private let state: Mutex<State>
  private let writeError: ControlActionTestError?

  var requestedStates: [ClamshellState] {
    state.withLock(\.requestedStates)
  }

  init(states: [ClamshellState], writeError: ControlActionTestError? = nil) {
    state = Mutex(State(states: states))
    self.writeError = writeError
  }

  func currentState() throws -> ClamshellState {
    try state.withLock { state in
      guard !state.states.isEmpty else {
        throw ControlActionTestError.unexpectedRead
      }
      return state.states.removeFirst()
    }
  }

  func setState(_ requestedState: ClamshellState) throws {
    state.withLock { state in
      state.requestedStates.append(requestedState)
    }
    if let writeError {
      throw writeError
    }
  }
}

private final class ReloadRecorder: Sendable {
  private let storage = Mutex(0)

  var count: Int {
    storage.withLock { $0 }
  }

  func record() {
    storage.withLock { $0 += 1 }
  }
}
