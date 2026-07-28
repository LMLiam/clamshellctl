public struct SudoersPolicy: Sendable, Equatable {
    public let username: String

    public init(username: String) throws {
        guard username != "root", !username.isEmpty, username.unicodeScalars.allSatisfy(Self.isSafe)
        else {
            throw ClamshellError.invalidUsername(username)
        }
        self.username = username
    }

    public var contents: String {
        """
        \(username) ALL=(root) NOPASSWD: \(PrivilegedPaths.helper) enable
        \(username) ALL=(root) NOPASSWD: \(PrivilegedPaths.helper) disable

        """
    }

    private static func isSafe(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 45, 46, 48...57, 65...90, 95, 97...122:
            true
        default:
            false
        }
    }
}
