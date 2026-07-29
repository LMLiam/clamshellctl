public struct EnablementDuration: Equatable, Sendable {
  public static let maximumSeconds = 30 * 24 * 60 * 60

  public let seconds: Int

  public init(parsing value: String) throws {
    guard
      let unit = value.last,
      let multiplier = Self.multiplier(for: unit)
    else {
      throw ClamshellError.invalidDuration(value)
    }

    let amountText = value.dropLast()
    guard
      !amountText.isEmpty,
      amountText.allSatisfy(\.isASCIIWholeNumber),
      let amount = Int(amountText),
      amount > 0
    else {
      throw ClamshellError.invalidDuration(value)
    }

    let (seconds, overflow) = amount.multipliedReportingOverflow(by: multiplier)
    guard !overflow, seconds <= Self.maximumSeconds else {
      throw ClamshellError.invalidDuration(value)
    }

    self.seconds = seconds
  }

  private static func multiplier(for unit: Character) -> Int? {
    switch unit {
    case "m":
      60
    case "h":
      60 * 60
    case "d":
      24 * 60 * 60
    default:
      nil
    }
  }
}

private extension Character {
  var isASCIIWholeNumber: Bool {
    asciiValue.map { (48...57).contains($0) } ?? false
  }
}
