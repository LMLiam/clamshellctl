import Foundation

public protocol TimerFileSystem: Sendable {
  func itemExists(at path: String) -> Bool
  func readData(at path: String) throws -> Data
  func writeAtomically(_ data: Data, to path: String) throws
  func removeItemIfExists(at path: String) throws
}
