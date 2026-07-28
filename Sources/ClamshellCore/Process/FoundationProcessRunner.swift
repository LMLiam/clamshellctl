import Dispatch
import Foundation

public struct FoundationProcessRunner: ProcessRunning {
    public init() {}

    public func run(_ executable: String, arguments: [String]) throws -> ProcessResult {
        let process = Process()
        let standardOutput = Pipe()
        let standardError = Pipe()

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = standardOutput
        process.standardError = standardError

        try process.run()

        let collector = ProcessOutputCollector(
            standardOutput: standardOutput.fileHandleForReading,
            standardError: standardError.fileHandleForReading
        )
        collector.start()
        process.waitUntilExit()

        let output = collector.waitForOutput()
        guard let outputString = String(data: output.standardOutput, encoding: .utf8) else {
            throw ClamshellError.invalidProcessOutput(
                executable: executable,
                stream: .standardOutput
            )
        }
        guard let errorString = String(data: output.standardError, encoding: .utf8) else {
            throw ClamshellError.invalidProcessOutput(
                executable: executable,
                stream: .standardError
            )
        }

        return ProcessResult(
            standardOutput: outputString,
            standardError: errorString,
            terminationStatus: process.terminationStatus
        )
    }
}

private final class ProcessOutputCollector: @unchecked Sendable {
    private let standardOutput: FileHandle
    private let standardError: FileHandle
    private let group = DispatchGroup()
    private let lock = NSLock()
    private var outputData = Data()
    private var errorData = Data()

    init(standardOutput: FileHandle, standardError: FileHandle) {
        self.standardOutput = standardOutput
        self.standardError = standardError
    }

    func start() {
        group.enter()
        DispatchQueue.global(qos: .utility).async {
            let data = self.standardOutput.readDataToEndOfFile()
            self.lock.withLock {
                self.outputData = data
            }
            self.group.leave()
        }

        group.enter()
        DispatchQueue.global(qos: .utility).async {
            let data = self.standardError.readDataToEndOfFile()
            self.lock.withLock {
                self.errorData = data
            }
            self.group.leave()
        }
    }

    func waitForOutput() -> (standardOutput: Data, standardError: Data) {
        group.wait()
        return lock.withLock {
            (outputData, errorData)
        }
    }
}
