import Testing

@testable import ClamshellCore

@Suite("pmset parser")
struct PowerSettingsParserTests {
  @Test("reads the enabled system state")
  func enabled() throws {
    let output = """
      System-wide power settings:
       SleepDisabled        1
      Currently in use:
       sleep                1
      """

    #expect(try PowerSettingsParser().state(from: output) == .enabled)
  }

  @Test("reads the disabled system state")
  func disabled() throws {
    let output = """
      System-wide power settings:
       SleepDisabled        0
      Currently in use:
       sleep                1
      """

    #expect(try PowerSettingsParser().state(from: output) == .disabled)
  }

  @Test("rejects output without a system state")
  func missingState() {
    let output = """
      Currently in use:
       sleep                1
      """

    #expect(throws: ClamshellError.self) {
      try PowerSettingsParser().state(from: output)
    }
  }

  @Test("rejects an unexpected system state value")
  func unexpectedValue() {
    let output = """
      System-wide power settings:
       SleepDisabled        2
      """

    #expect(throws: ClamshellError.self) {
      try PowerSettingsParser().state(from: output)
    }
  }

  @Test("rejects a malformed system state")
  func malformedValue() {
    let output = """
      System-wide power settings:
       SleepDisabled        1 unexpected
      """

    #expect(throws: ClamshellError.self) {
      try PowerSettingsParser().state(from: output)
    }
  }
}
