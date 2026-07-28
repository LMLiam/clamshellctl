import Foundation
import Testing

@testable import ClamshellCore

@Suite("Clamshell service")
struct ClamshellServiceTests {
    @Test(
        "applies only required state transitions",
        arguments: [
            (ClamshellState.disabled, ClamshellState.disabled, false),
            (.disabled, .enabled, true),
            (.enabled, .enabled, false),
            (.enabled, .disabled, true),
        ]
    )
    func transition(
        current: ClamshellState,
        requested: ClamshellState,
        shouldMutate: Bool
    ) throws {
        let power = RecordingPowerSettings(current: current)
        let service = ClamshellService(stateReader: power, stateWriter: power)

        let result = try service.set(requested)

        #expect(
            result
                == TransitionResult(
                    previous: current,
                    current: requested,
                    didChange: shouldMutate
                )
        )
        #expect(power.requestedStates == (shouldMutate ? [requested] : []))
    }

    @Test("rejects a mutation that does not reach the requested state")
    func verificationFailure() {
        let power = RecordingPowerSettings(
            current: .disabled,
            stateAfterMutation: .disabled
        )
        let service = ClamshellService(stateReader: power, stateWriter: power)

        #expect(
            throws: ClamshellError.stateVerificationFailed(
                expected: .enabled,
                actual: .disabled
            )
        ) {
            try service.set(.enabled)
        }
    }

    @Test("toggles from a fresh state and verifies the result")
    func toggle() throws {
        let power = RecordingPowerSettings(current: .enabled)
        let service = ClamshellService(stateReader: power, stateWriter: power)

        let result = try service.toggle()

        #expect(
            result
                == TransitionResult(
                    previous: .enabled,
                    current: .disabled,
                    didChange: true
                )
        )
        #expect(power.requestedStates == [.disabled])
        #expect(power.readCount == 2)
    }
}

private final class RecordingPowerSettings:
    PowerStateReading,
    PowerStateWriting,
    @unchecked Sendable
{
    private let lock = NSLock()
    private let stateAfterMutation: ClamshellState?
    private var state: ClamshellState
    private var recordedStates: [ClamshellState] = []
    private var recordedReadCount = 0

    init(current: ClamshellState, stateAfterMutation: ClamshellState? = nil) {
        state = current
        self.stateAfterMutation = stateAfterMutation
    }

    var requestedStates: [ClamshellState] {
        lock.withLock { recordedStates }
    }

    var readCount: Int {
        lock.withLock { recordedReadCount }
    }

    func currentState() throws -> ClamshellState {
        lock.withLock {
            recordedReadCount += 1
            return state
        }
    }

    func setState(_ requested: ClamshellState) throws {
        lock.withLock {
            recordedStates.append(requested)
            state = stateAfterMutation ?? requested
        }
    }
}
