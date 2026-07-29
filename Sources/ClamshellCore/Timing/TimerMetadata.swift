import Foundation

public struct TimerMetadata: Codable, Equatable, Sendable {
  public static let currentSchemaVersion = 1

  public let schemaVersion: Int
  public let deadline: Date
  public let executablePath: String

  public init(deadline: Date, executablePath: String) throws {
    try self.init(
      schemaVersion: Self.currentSchemaVersion,
      deadline: deadline,
      executablePath: executablePath
    )
  }

  public init(decoding data: Data) throws {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    self = try decoder.decode(Self.self, from: data)
  }

  public func encoded() throws -> Data {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return try encoder.encode(self)
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      schemaVersion: container.decode(Int.self, forKey: .schemaVersion),
      deadline: container.decode(Date.self, forKey: .deadline),
      executablePath: container.decode(String.self, forKey: .executablePath)
    )
  }

  private init(
    schemaVersion: Int,
    deadline: Date,
    executablePath: String
  ) throws {
    guard schemaVersion == Self.currentSchemaVersion else {
      throw ClamshellError.unsupportedTimerMetadataVersion(schemaVersion)
    }
    guard NSString(string: executablePath).isAbsolutePath else {
      throw ClamshellError.invalidTimerExecutablePath(executablePath)
    }

    self.schemaVersion = schemaVersion
    self.deadline = deadline
    self.executablePath = executablePath
  }
}
