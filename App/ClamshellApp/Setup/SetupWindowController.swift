import AppKit
import SwiftUI

@MainActor
final class SetupWindowController {
  private let window: NSWindow

  init(model: SetupModel) {
    let content = NSHostingController(rootView: SetupView(model: model))
    window = NSWindow(contentViewController: content)
    window.title = "Clamshell"
    window.styleMask = [.titled, .closable]
    window.isReleasedWhenClosed = false
    window.center()
  }

  func show() {
    window.makeKeyAndOrderFront(nil)
    NSApp.activate()
  }
}
