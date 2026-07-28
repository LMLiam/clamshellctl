import Foundation
import Testing

@testable import ClamshellCore

@Suite("Power settings client")
struct PowerSettingsClientTests {
    @Test("reads the battery state with pmset custom settings")
    func currentState() throws {
        let runner = RecordingProcessRunner(
            result: ProcessResult(
                standardOutput: """
                    Battery Power:
                     disablesleep         1
                    AC Power:
                     disablesleep         0
                    """,
                standardError: "",
                terminationStatus: 0
            )
        )

        let state = try PowerSettingsClient(runner: runner).currentState()

        #expect(state == .enabled)
        #expect(
            runner.invocations == [
                ProcessInvocation(
                    executable: "/usr/bin/pmset",
                    arguments: ["-g", "custom"]
                )
            ])
    }

    @Test("preserves a failed pmset exit status and stderr")
    func processFailure() {
        let runner = RecordingProcessRunner(
            result: ProcessResult(
                standardOutput: "",
                standardError: "pmset failed",
                terminationStatus: 64
            )
        )

        #expect(
            throws: ClamshellError.processFailed(
                executable: "/usr/bin/pmset",
                terminationStatus: 64,
                standardError: "pmset failed"
            )
        ) {
            try PowerSettingsClient(runner: runner).currentState()
        }
    }
}

private struct ProcessInvocation: Equatable {
    let executable: String
    let arguments: [String]
}

private final class RecordingProcessRunner: ProcessRunning, @unchecked Sendable {
    private let lock = NSLock()
    private let result: ProcessResult
    private var recordedInvocations: [ProcessInvocation] = []

    init(result: ProcessResult) {
        self.result = result
    }

    var invocations: [ProcessInvocation] {
        lock.withLock {
            recordedInvocations
        }
    }

    func run(_ executable: String, arguments: [String]) throws -> ProcessResult {
        lock.withLock {
            recordedInvocations.append(
                ProcessInvocation(executable: executable, arguments: arguments)
            )
        }
        return result
    }
}
