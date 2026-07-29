import SwiftUI

@main
struct ClamshellApp: App {
  @State private var setupModel = SetupComposition.makeModel()

  var body: some Scene {
    Window("Clamshell", id: "setup") {
      SetupView(model: setupModel)
    }
    .windowResizability(.contentSize)
  }
}
