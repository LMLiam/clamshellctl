import Testing

@testable import ClamshellCore

@Suite("pmset parser")
struct PowerSettingsParserTests {
    @Test("reads enabled from Battery Power")
    func enabled() throws {
        let output = """
            Battery Power:
             sleep                1
             disablesleep         1
            AC Power:
             sleep                1
             disablesleep         0
            """

        #expect(try PowerSettingsParser().batteryState(from: output) == .enabled)
    }

    @Test("reads disabled from Battery Power")
    func disabled() throws {
        let output = """
            Battery Power:
             sleep                1
             disablesleep         0
            AC Power:
             disablesleep         1
            """

        #expect(try PowerSettingsParser().batteryState(from: output) == .disabled)
    }

    @Test("treats an absent battery disablesleep key as disabled")
    func absentMeansDisabled() throws {
        let output = """
            Battery Power:
             sleep                1
            AC Power:
             disablesleep         1
            """

        #expect(try PowerSettingsParser().batteryState(from: output) == .disabled)
    }

    @Test("rejects output without a Battery Power section")
    func missingBatterySection() {
        #expect(throws: ClamshellError.self) {
            try PowerSettingsParser().batteryState(
                from: "AC Power:\n disablesleep 1"
            )
        }
    }

    @Test("rejects an unexpected battery disablesleep value")
    func unexpectedValue() {
        let output = """
            Battery Power:
             disablesleep         2
            AC Power:
             disablesleep         0
            """

        #expect(throws: ClamshellError.self) {
            try PowerSettingsParser().batteryState(from: output)
        }
    }
}
