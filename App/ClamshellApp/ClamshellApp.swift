import SwiftUI

@main
struct ClamshellApp: App {
  @NSApplicationDelegateAdaptor(ControlActionApplicationDelegate.self)
  private var applicationDelegate

  var body: some Scene {
    Settings {
      EmptyView()
    }
  }
}
