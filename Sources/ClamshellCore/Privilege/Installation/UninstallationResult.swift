public struct UninstallationResult: Sendable, Equatable {
    public let removedPaths: [String]

    public init(removedPaths: [String]) {
        self.removedPaths = removedPaths
    }
}
