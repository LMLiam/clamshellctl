import AppKit

@MainActor
enum ApplicationLaunchPolicy {
  static func shouldShowSetup(userInfo: [AnyHashable: Any]?) -> Bool {
    userInfo?[NSApplication.launchIsDefaultUserInfoKey] as? Bool ?? true
  }
}
