import Foundation

struct FoundationCompanionPayloadInspector: CompanionPayloadInspecting {
  func isRegularFile(at url: URL) -> Bool {
    var isDirectory = ObjCBool(false)
    return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
      && !isDirectory.boolValue
  }
}
