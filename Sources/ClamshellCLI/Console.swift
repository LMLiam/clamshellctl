import Foundation

struct Console {
    private let standardOutput: FileHandle

    init(standardOutput: FileHandle = .standardOutput) {
        self.standardOutput = standardOutput
    }

    func writeLine(_ line: String) {
        standardOutput.write(Data("\(line)\n".utf8))
    }
}
