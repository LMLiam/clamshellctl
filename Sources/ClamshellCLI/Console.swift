import ClamshellCore
import Foundation

struct Console {
  private let standardOutput: FileHandle
  private let isQuiet: Bool

  init(isQuiet: Bool, standardOutput: FileHandle = .standardOutput) {
    self.isQuiet = isQuiet
    self.standardOutput = standardOutput
  }

  func writeLine(_ line: String) {
    guard !isQuiet else {
      return
    }
    standardOutput.write(Data("\(line)\n".utf8))
  }

  func writeTransition(_ result: TransitionResult) {
    let qualifier = result.didChange ? "" : "already "
    writeLine("Battery clamshell mode: \(qualifier)\(result.current.rawValue)")
  }
}
