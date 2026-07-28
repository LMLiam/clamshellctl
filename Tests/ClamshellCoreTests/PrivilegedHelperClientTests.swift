import Foundation
import Testing

@testable import ClamshellCore

@Suite("Privileged helper client")
struct PrivilegedHelperClientTests {
    @Test(
        "uses non-interactive sudo for one exact helper action",
        arguments: [
            (ClamshellState.enabled, "enable"),
            (.disabled, "disable"),
        ]
    )
    func exactInvocation(state: ClamshellState, action: String) throws {
        let runner = HelperRecordingRunner(
            result: ProcessResult(
                standardOutput: "",
                standardError: "",
                terminationStatus: 0
            )
        )

        try PrivilegedHelperClient(runner: runner).setState(state)

        #expect(
            runner.invocations == [
                HelperInvocation(
                    executable: "/usr/bin/sudo",
                    arguments: [
                        "-n",
                        "/usr/local/libexec/clamshellctl-helper",
                        action,
                    ]
                )
            ])
    }

    @Test("replaces sudo failure details with setup guidance")
    func sudoFailure() {
        let runner = HelperRecordingRunner(
            result: ProcessResult(
                standardOutput: "arbitrary output",
                standardError: "sensitive arbitrary stderr",
                terminationStatus: 1
            )
        )

        #expect(
            throws: ClamshellError.privilegedHelperUnavailable(
                setupCommand: #"sudo "$(brew --prefix)/bin/clamshellctl" setup"#
            )
        ) {
            try PrivilegedHelperClient(runner: runner).setState(.enabled)
        }
    }
}

private struct HelperInvocation: Equatable {
    let executable: String
    let arguments: [String]
}

private final class HelperRecordingRunner: ProcessRunning, @unchecked Sendable {
    private let lock = NSLock()
    private let result: ProcessResult
    private var recordedInvocations: [HelperInvocation] = []

    init(result: ProcessResult) {
        self.result = result
    }

    var invocations: [HelperInvocation] {
        lock.withLock { recordedInvocations }
    }

    func run(_ executable: String, arguments: [String]) throws -> ProcessResult {
        lock.withLock {
            recordedInvocations.append(
                HelperInvocation(executable: executable, arguments: arguments)
            )
        }
        return result
    }
}
