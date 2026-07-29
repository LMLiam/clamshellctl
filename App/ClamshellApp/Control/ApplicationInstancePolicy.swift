import Foundation

struct ApplicationInstancePolicy: Sendable {
  struct Instance: Equatable, Sendable {
    let processIdentifier: Int32
    let bundleURL: URL?
    let launchDate: Date?
  }

  enum Resolution: Equatable, Sendable {
    case continueAndTerminate([Int32])
    case terminateCurrent
  }

  private static let installedApplicationURL =
    URL(fileURLWithPath: "/Applications/Clamshell.app").standardizedFileURL

  func resolve(current: Instance, running: [Instance]) -> Resolution {
    var instancesByProcessIdentifier: [Int32: Instance] = [:]
    for instance in running {
      instancesByProcessIdentifier[instance.processIdentifier] = instance
    }
    instancesByProcessIdentifier[current.processIdentifier] = current
    let instances = Array(instancesByProcessIdentifier.values)

    guard var selected = instances.first else {
      return .continueAndTerminate([])
    }
    for candidate in instances.dropFirst() where isPreferred(candidate, to: selected) {
      selected = candidate
    }
    guard selected.processIdentifier == current.processIdentifier else {
      return .terminateCurrent
    }

    let otherProcessIdentifiers = instances
      .lazy
      .map(\.processIdentifier)
      .filter { $0 != current.processIdentifier }
      .sorted()
    return .continueAndTerminate(otherProcessIdentifiers)
  }

  private func isPreferred(_ candidate: Instance, to selected: Instance) -> Bool {
    let candidateIsInstalled = isInstalled(candidate)
    let selectedIsInstalled = isInstalled(selected)
    if candidateIsInstalled != selectedIsInstalled {
      return candidateIsInstalled
    }

    let candidateLaunchDate = candidate.launchDate ?? .distantPast
    let selectedLaunchDate = selected.launchDate ?? .distantPast
    if candidateLaunchDate != selectedLaunchDate {
      return candidateLaunchDate > selectedLaunchDate
    }
    return candidate.processIdentifier > selected.processIdentifier
  }

  private func isInstalled(_ instance: Instance) -> Bool {
    instance.bundleURL?.standardizedFileURL == Self.installedApplicationURL
  }
}
