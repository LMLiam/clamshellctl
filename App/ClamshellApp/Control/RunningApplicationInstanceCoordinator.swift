import AppKit

@MainActor
struct RunningApplicationInstanceCoordinator {
  private let policy = ApplicationInstancePolicy()

  func claimCurrentInstance() -> Bool {
    let current = NSRunningApplication.current
    guard let bundleIdentifier = current.bundleIdentifier else {
      return true
    }

    let runningApplications = NSRunningApplication.runningApplications(
      withBundleIdentifier: bundleIdentifier
    )
    let resolution = policy.resolve(
      current: instance(for: current),
      running: runningApplications.map(instance)
    )

    switch resolution {
    case .terminateCurrent:
      terminate(current)
      return false
    case let .continueAndTerminate(processIdentifiers):
      let processIdentifierSet = Set(processIdentifiers)
      for application in runningApplications
      where processIdentifierSet.contains(application.processIdentifier) {
        terminate(application)
      }
      return true
    }
  }

  private func instance(for application: NSRunningApplication) -> ApplicationInstancePolicy.Instance
  {
    ApplicationInstancePolicy.Instance(
      processIdentifier: application.processIdentifier,
      bundleURL: application.bundleURL,
      launchDate: application.launchDate
    )
  }

  private func terminate(_ application: NSRunningApplication) {
    if !application.terminate() {
      application.forceTerminate()
    }
  }
}
