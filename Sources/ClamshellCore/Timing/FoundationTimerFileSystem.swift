import Foundation

public struct FoundationTimerFileSystem: TimerFileSystem {
  public init() {}

  public func itemExists(at path: String) -> Bool {
    FileManager.default.fileExists(atPath: path)
  }

  public func readData(at path: String) throws -> Data {
    try Data(contentsOf: URL(fileURLWithPath: path))
  }

  public func writeAtomically(_ data: Data, to path: String) throws {
    let fileURL = URL(fileURLWithPath: path)
    try FileManager.default.createDirectory(
      at: fileURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try data.write(to: fileURL, options: .atomic)
  }

  public func removeItemIfExists(at path: String) throws {
    guard itemExists(at: path) else {
      return
    }
    try FileManager.default.removeItem(atPath: path)
  }
}
