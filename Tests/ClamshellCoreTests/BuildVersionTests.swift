import Testing

@testable import ClamshellCore

@Suite("Build version")
struct BuildVersionTests {
    @Test("starts at the planned initial version")
    func initialVersion() {
        #expect(BuildVersion.current == "0.1.0")
    }
}
