import AppKit
import Foundation

@MainActor
final class ControlActionApplicationDelegate: NSObject, NSApplicationDelegate {
  private let handler = ControlActionHandler.live
  private lazy var setupWindowController = SetupWindowController(
    model: SetupComposition.makeModel()
  )

  func applicationWillFinishLaunching(_ notification: Notification) {
    NSAppleEventManager.shared().setEventHandler(
      self,
      andSelector: #selector(handleGetURL(_:withReplyEvent:)),
      forEventClass: AEEventClass(kInternetEventClass),
      andEventID: AEEventID(kAEGetURL)
    )
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    if ApplicationLaunchPolicy.shouldShowSetup(userInfo: notification.userInfo) {
      setupWindowController.show()
    }
  }

  func applicationShouldHandleReopen(
    _ sender: NSApplication,
    hasVisibleWindows flag: Bool
  ) -> Bool {
    if !flag {
      setupWindowController.show()
    }
    return false
  }

  func applicationWillTerminate(_ notification: Notification) {
    NSAppleEventManager.shared().removeEventHandler(
      forEventClass: AEEventClass(kInternetEventClass),
      andEventID: AEEventID(kAEGetURL)
    )
  }

  @objc
  private func handleGetURL(
    _ event: NSAppleEventDescriptor,
    withReplyEvent replyEvent: NSAppleEventDescriptor
  ) {
    guard
      let value = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
      let url = URL(string: value)
    else {
      return
    }

    let handler = handler
    Task.detached {
      _ = handler.handle(url)
    }
  }
}
