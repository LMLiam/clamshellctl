import Testing

@testable import ClamshellCore

@Suite("Sudoers policy")
struct SudoersPolicyTests {
  @Test(
    "accepts safe ASCII account names",
    arguments: ["liam", "Liam1", "liam.name", "liam_name", "liam-name"]
  )
  func acceptedUsername(username: String) throws {
    #expect(try SudoersPolicy(username: username).username == username)
  }

  @Test("generates only the two exact helper commands")
  func exactPolicy() throws {
    let policy = try SudoersPolicy(username: "liam")

    #expect(
      policy.contents
        == """
        liam ALL=(root) NOPASSWD: /Library/PrivilegedHelperTools/clamshellctl-helper enable
        liam ALL=(root) NOPASSWD: /Library/PrivilegedHelperTools/clamshellctl-helper disable

        """
    )
  }

  @Test("rejects unsafe or ambiguous account names")
  func rejectedUsername() {
    let invalidUsernames = [
      "",
      "root",
      "liam smith",
      "../liam",
      "liam/name",
      "liam:wheel",
      "liam;command",
      "liam\nroot ALL=(ALL) ALL",
      "líam",
    ]

    for username in invalidUsernames {
      #expect(throws: ClamshellError.invalidUsername(username)) {
        try SudoersPolicy(username: username)
      }
    }
  }
}
