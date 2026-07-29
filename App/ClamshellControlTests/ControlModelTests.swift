import ClamshellControlModel
import ClamshellCore
import Testing

@Suite("Control model")
struct ControlModelTests {
  @Test("maps the current power state to a Boolean value")
  func currentValue() throws {
    let enabledPower = RecordingPower(states: [.enabled])
    let disabledPower = RecordingPower(states: [.disabled])

    #expect(try ControlModel(stateReader: enabledPower, stateWriter: enabledPower).currentValue())
    #expect(
      try !ControlModel(stateReader: disabledPower, stateWriter: disabledPower).currentValue())
  }

  @Test("does not mutate an already selected state")
  func unchangedState() throws {
    let power = RecordingPower(states: [.enabled])
    let model = ControlModel(stateReader: power, stateWriter: power)

    try model.setValue(true)

    #expect(power.requestedStates.isEmpty)
    #expect(power.states.isEmpty)
  }

  @Test("requests one exact state and verifies the result")
  func changedState() throws {
    let power = RecordingPower(states: [.disabled, .enabled])
    let model = ControlModel(stateReader: power, stateWriter: power)

    try model.setValue(true)

    #expect(power.requestedStates == [.enabled])
    #expect(power.states.isEmpty)
  }

  @Test("propagates a helper failure without another state read")
  func helperFailure() {
    let power = RecordingPower(states: [.disabled], writeError: .helperFailed)
    let model = ControlModel(stateReader: power, stateWriter: power)

    #expect(throws: ControlTestError.helperFailed) {
      try model.setValue(true)
    }
    #expect(power.requestedStates == [.enabled])
    #expect(power.states.isEmpty)
  }

  @Test("rejects a result that does not match the requested state")
  func verificationFailure() {
    let power = RecordingPower(states: [.disabled, .disabled])
    let model = ControlModel(stateReader: power, stateWriter: power)

    #expect(throws: ClamshellError.self) {
      try model.setValue(true)
    }
    #expect(power.requestedStates == [.enabled])
    #expect(power.states.isEmpty)
  }
}

private enum ControlTestError: Error {
  case helperFailed
  case unexpectedRead
}

private final class RecordingPower: PowerStateReading, PowerStateWriting, @unchecked Sendable {
  var states: [ClamshellState]
  private(set) var requestedStates: [ClamshellState] = []
  private let writeError: ControlTestError?

  init(states: [ClamshellState], writeError: ControlTestError? = nil) {
    self.states = states
    self.writeError = writeError
  }

  func currentState() throws -> ClamshellState {
    guard !states.isEmpty else {
      throw ControlTestError.unexpectedRead
    }
    return states.removeFirst()
  }

  func setState(_ state: ClamshellState) throws {
    requestedStates.append(state)
    if let writeError {
      throw writeError
    }
  }
}
