import AppKit
import SwiftUI

@MainActor
final class SetupWindowController {
  private let window: NSWindow

  convenience init(model: SetupModel) {
    let content = NSHostingController(rootView: SetupView(model: model))
    let window = NSWindow(contentViewController: content)
    window.title = "Clamshell"
    window.styleMask = [.titled, .closable]
    window.isReleasedWhenClosed = false
    window.center()
    self.init(window: window)
  }

  init(window: NSWindow) {
    self.window = window
  }

  func show() {
    NSApp.activate()
    window.makeKeyAndOrderFront(nil)
    window.orderFrontRegardless()
  }
}
