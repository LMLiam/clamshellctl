import Foundation

public struct PowerSettingsParser: Sendable {
  public init() {}

  /// Treats a missing `disablesleep` entry as disabled and rejects malformed values.
  public func batteryState(from output: String) throws -> ClamshellState {
    let lines = output.split(
      omittingEmptySubsequences: false,
      whereSeparator: \Character.isNewline
    )

    guard
      let batteryHeader = lines.firstIndex(where: {
        $0.trimmingCharacters(in: .whitespaces) == "Battery Power:"
      })
    else {
      throw ClamshellError.unrecognisedPowerSettings
    }

    for line in lines[lines.index(after: batteryHeader)...] {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      guard !trimmed.isEmpty else {
        continue
      }
      guard line.first?.isWhitespace == true else {
        break
      }

      let fields = trimmed.split(whereSeparator: \Character.isWhitespace)
      guard fields.first == "disablesleep" else {
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

    return .disabled
  }
}
