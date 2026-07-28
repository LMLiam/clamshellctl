import Foundation
import Testing

@testable import ClamshellCore

@Suite("Privileged power mutation")
struct PowerMutationTests {
    @Test(
        "accepts one exact helper action",
        arguments: [
            (["enable"], ClamshellState.enabled),
            (["disable"], ClamshellState.disabled),
        ]
    )
    func acceptedArguments(arguments: [String], expectedState: ClamshellState) throws {
        #expect(try PowerMutation(rawArguments: arguments).state == expectedState)
    }

    @Test("rejects every other helper argument shape")
    func rejectedArguments() {
        let invalidArguments = [
            [],
            ["enable", "disable"],
            ["--enable"],
            ["Enable"],
            ["1"],
            ["enable", "extra"],
        ]

        for arguments in invalidArguments {
            #expect(throws: ClamshellError.invalidHelperArguments) {
                try PowerMutation(rawArguments: arguments)
            }
        }
    }

    @Test(
        "maps states to battery-only pmset arguments",
        arguments: [
            (ClamshellState.enabled, "1"),
            (.disabled, "0"),
        ]
    )
    func pmsetArguments(state: ClamshellState, value: String) throws {
        let runner = MutationRecordingRunner(
            result: ProcessResult(
                standardOutput: "",
                standardError: "",
                terminationStatus: 0
            )
        )

        try PowerSettingsClient(runner: runner).setState(state)

        #expect(
            runner.invocations == [
                MutationInvocation(
                    executable: "/usr/bin/pmset",
                    arguments: ["-b", "disablesleep", value]
                )
            ])
    }

    @Test("preserves a failed mutation exit status and stderr")
    func mutationFailure() {
        let runner = MutationRecordingRunner(
            result: ProcessResult(
                standardOutput: "",
                standardError: "permission denied",
                terminationStatus: 77
            )
        )

        #expect(
            throws: ClamshellError.processFailed(
                executable: "/usr/bin/pmset",
                terminationStatus: 77,
                standardError: "permission denied"
            )
        ) {
            try PowerSettingsClient(runner: runner).setState(.enabled)
        }
    }
}

private struct MutationInvocation: Equatable {
    let executable: String
    let arguments: [String]
}

private final class MutationRecordingRunner: ProcessRunning, @unchecked Sendable {
    private let lock = NSLock()
    private let result: ProcessResult
    private var recordedInvocations: [MutationInvocation] = []

    init(result: ProcessResult) {
        self.result = result
    }

    var invocations: [MutationInvocation] {
        lock.withLock { recordedInvocations }
    }

    func run(_ executable: String, arguments: [String]) throws -> ProcessResult {
        lock.withLock {
            recordedInvocations.append(
                MutationInvocation(executable: executable, arguments: arguments)
            )
        }
        return result
    }
}
