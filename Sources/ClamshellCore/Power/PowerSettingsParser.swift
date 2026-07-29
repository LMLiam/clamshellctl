import Foundation

public struct PowerSettingsParser: Sendable {
  public init() {}

  public func state(from output: String) throws -> ClamshellState {
    let lines = output.split(
      omittingEmptySubsequences: false,
      whereSeparator: \Character.isNewline
    )

    for line in lines {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      let fields = trimmed.split(whereSeparator: \Character.isWhitespace)
      guard fields.first == "SleepDisabled" else {
        continue
      }
      guard fields.count == 2 else {
        throw ClamshellError.unrecognisedPowerSettings
      }

      switch fields[1] {
      case "1":
        return .enabled
      case "0":
        return .disabled
      default:
        throw ClamshellError.unrecognisedPowerSettings
      }
    }

    throw ClamshellError.unrecognisedPowerSettings
  }
}
