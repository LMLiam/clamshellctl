import AppKit
import Testing

@testable import Clamshell

@Suite("Setup window controller")
@MainActor
struct SetupWindowControllerTests {
  @Test("raises the setup window above other applications")
  func raisesSetupWindow() {
    let window = RecordingWindow()
    let controller = SetupWindowController(window: window)

    controller.show()

    #expect(window.presentationCalls == [.makeKeyAndOrderFront, .orderFrontRegardless])
  }
}

@MainActor
private final class RecordingWindow: NSWindow {
  enum PresentationCall: Equatable {
    case makeKeyAndOrderFront
    case orderFrontRegardless
  }

  private(set) var presentationCalls: [PresentationCall] = []

  override func makeKeyAndOrderFront(_ sender: Any?) {
    presentationCalls.append(.makeKeyAndOrderFront)
  }

  override func orderFrontRegardless() {
    presentationCalls.append(.orderFrontRegardless)
  }
}
