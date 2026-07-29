# Control Centre action relay implementation plan

**Goal:** Prove that an ad-hoc-signed Control Centre extension can send an exact
battery clamshell request to Clamshell without visible app activation.

**Architecture:** The extension owns the `SetValueIntent` and opens one fixed
custom URL. A small static framework defines the URL contract for the extension
and app. The app validates the URL, calls the existing `ControlModel`, and asks
Control Centre to read the verified `pmset` state again.

**Tech stack:** Swift 6, Swift Testing, SwiftUI, AppKit, App Intents, WidgetKit,
XcodeGen, `ClamshellCore`, and ad-hoc macOS code signing.

**Working rules:** Use test-driven development. Stage only the listed files.
Use `verb(area): description` commit messages. Do not stage `.vscode/`. Do not
publish or push a DMG until all manual feasibility checks pass.

---

## File map

```text
App/ClamshellControlProtocol/ControlActionRequest.swift
  Exact cross-process request and URL validation.

App/ClamshellControl/Intent/WorkspaceControlActionRequester.swift
  Non-activating AppKit request delivery from the extension.

App/ClamshellControl/Intent/SetBatteryClamshellIntent.swift
  Background SetValueIntent that selects one typed request.

App/ClamshellControl/Intent/ClamshellControlIntents.swift
  Extension-only App Intents package declaration.

App/ClamshellApp/Control/ControlActionHandler.swift
  Validated request execution, logging, and control reload.

App/ClamshellApp/Control/ControlActionApplicationDelegate.swift
  Cold-launch and warm-launch URL event delivery.

App/ClamshellApp/Control/ApplicationLaunchPolicy.swift
  Pure decision for visible setup launches and background action launches.

App/ClamshellApp/Setup/SetupWindowController.swift
  AppKit owner for the optional SwiftUI setup window.

App/ClamshellApp/ClamshellApp.swift
  Application delegate composition.

App/ClamshellApp/Info.plist
  Private URL scheme registration.

App/ClamshellControlTests/ControlActionRequestTests.swift
  Exact URL contract tests.

App/ClamshellControlTests/WorkspaceControlActionRequesterTests.swift
  Extension relay tests without opening an app.

App/ClamshellControlTests/SetBatteryClamshellIntentTests.swift
  Extension execution-mode regression test.

App/ClamshellAppTests/ControlActionHandlerTests.swift
  App-side validation, execution, failure, and reload tests.

App/ClamshellAppTests/ApplicationLaunchPolicyTests.swift
  Visible default launch and hidden URL launch tests.

project.yml
  Shared protocol target and corrected target dependencies.

docs/control-feasibility-test.md
  Recorded automated and manual feasibility results.
```

Delete `App/ClamshellApp/ClamshellAppIntents.swift`. The main app must not import
or register `ClamshellControlIntent`.

## Task 1: Add the exact request contract

**Files:**

- Create: `App/ClamshellControlProtocol/ControlActionRequest.swift`
- Create: `App/ClamshellControlTests/ControlActionRequestTests.swift`
- Modify: `project.yml`

- [ ] **Step 1: Add the protocol target and test dependency**

Add this static framework target to `project.yml`:

```yaml
  ClamshellControlProtocol:
    type: framework.static
    platform: macOS
    sources:
      - App/ClamshellControlProtocol
    settings:
      base:
        GENERATE_INFOPLIST_FILE: YES
        PRODUCT_BUNDLE_IDENTIFIER: uk.co.lmliam.clamshell.control-protocol
```

Add `ClamshellControlProtocol` as a linked, non-embedded dependency of
`ClamshellApp`, `ClamshellControlIntent`, `ClamshellAppTests`, and
`ClamshellControlTests`.

- [ ] **Step 2: Write the failing URL contract tests**

```swift
import Foundation
import Testing
@testable import ClamshellControlProtocol

@Suite("Control action request")
struct ControlActionRequestTests {
  @Test("maps each request to one exact URL")
  func exactURLs() {
    #expect(
      ControlActionRequest.enableBatteryClamshellMode.url.absoluteString
        == "clamshellctl://battery-clamshell/enable"
    )
    #expect(
      ControlActionRequest.disableBatteryClamshellMode.url.absoluteString
        == "clamshellctl://battery-clamshell/disable"
    )
  }

  @Test("parses both exact URLs")
  func validURLs() throws {
    let enableURL = try #require(
      URL(string: "clamshellctl://battery-clamshell/enable")
    )
    let disableURL = try #require(
      URL(string: "clamshellctl://battery-clamshell/disable")
    )

    #expect(ControlActionRequest(url: enableURL) == .enableBatteryClamshellMode)
    #expect(ControlActionRequest(url: disableURL) == .disableBatteryClamshellMode)
  }

  @Test(
    "rejects every URL outside the exact contract",
    arguments: [
      "other://battery-clamshell/enable",
      "clamshellctl://other/enable",
      "clamshellctl://battery-clamshell/toggle",
      "clamshellctl://battery-clamshell/enable?command=other",
      "clamshellctl://battery-clamshell/enable#other",
      "clamshellctl://user@battery-clamshell/enable",
    ]
  )
  func invalidURL(value: String) throws {
    let url = try #require(URL(string: value))
    #expect(ControlActionRequest(url: url) == nil)
  }
}
```

- [ ] **Step 3: Generate the project and confirm the missing type**

Run:

```bash
xcodegen generate
xcodebuild -project Clamshell.xcodeproj -scheme ClamshellControlTests \
  -configuration Release -destination 'platform=macOS,arch=arm64' \
  CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= test
```

Expected: compilation fails because `ControlActionRequest` does not exist.

- [ ] **Step 4: Implement the closed request type**

```swift
import Foundation

public enum ControlActionRequest: Equatable, Sendable {
  case enableBatteryClamshellMode
  case disableBatteryClamshellMode

  public init?(url: URL) {
    switch url.absoluteString {
    case Self.enableURL.absoluteString:
      self = .enableBatteryClamshellMode
    case Self.disableURL.absoluteString:
      self = .disableBatteryClamshellMode
    default:
      return nil
    }
  }

  public var isEnabled: Bool {
    self == .enableBatteryClamshellMode
  }

  public var url: URL {
    switch self {
    case .enableBatteryClamshellMode:
      Self.enableURL
    case .disableBatteryClamshellMode:
      Self.disableURL
    }
  }

  private static let enableURL = URL(
    string: "clamshellctl://battery-clamshell/enable"
  )!
  private static let disableURL = URL(
    string: "clamshellctl://battery-clamshell/disable"
  )!
}
```

The force unwraps apply only to fixed source-code constants. No external text
can reach them.

- [ ] **Step 5: Run the contract tests**

Run the command from Step 3 again.

Expected: `ControlActionRequestTests` passes.

- [ ] **Step 6: Commit the contract**

```bash
git add project.yml \
  App/ClamshellControlProtocol/ControlActionRequest.swift \
  App/ClamshellControlTests/ControlActionRequestTests.swift
git commit -m "feat(control): define background action contract"
```

## Task 2: Relay the intent from the extension

**Files:**

- Create: `App/ClamshellControl/Intent/WorkspaceControlActionRequester.swift`
- Modify: `App/ClamshellControl/Intent/SetBatteryClamshellIntent.swift`
- Modify: `App/ClamshellControl/BatteryClamshellControl.swift`
- Delete: `App/ClamshellControl/SetBatteryClamshellIntent.swift`
- Modify: `App/ClamshellControlTests/SetBatteryClamshellIntentTests.swift`
- Create: `App/ClamshellControlTests/WorkspaceControlActionRequesterTests.swift`
- Modify: `project.yml`

- [ ] **Step 1: Write the failing requester tests**

```swift
import Foundation
import Testing
@testable import ClamshellControlIntent
import ClamshellControlProtocol

@Suite("Workspace control action requester")
struct WorkspaceControlActionRequesterTests {
  @Test("opens the exact URL for the request")
  func exactURL() async throws {
    let recorder = URLRecorder()
    let requester = WorkspaceControlActionRequester { url in
      await recorder.record(url)
    }

    try await requester.request(.enableBatteryClamshellMode)

    #expect(
      await recorder.url?.absoluteString
        == "clamshellctl://battery-clamshell/enable"
    )
  }
}

private actor URLRecorder {
  private(set) var url: URL?

  func record(_ url: URL) {
    self.url = url
  }
}
```

Replace the existing intent test with:

```swift
import AppIntents
import Testing
@testable import ClamshellControlIntent

@Suite("Battery clamshell intent")
struct SetBatteryClamshellIntentTests {
  @Test("runs in the control extension")
  func extensionExecution() {
    #expect(SetBatteryClamshellIntent.supportedModes == .background)
  }
}
```

- [ ] **Step 2: Confirm both tests fail**

Run the `ClamshellControlTests` command from Task 1.

Expected: the requester type is missing and the execution-mode assertion fails.

- [ ] **Step 3: Implement non-activating URL delivery**

```swift
import AppKit
import ClamshellControlProtocol

public struct WorkspaceControlActionRequester: Sendable {
  public typealias OpenURL = @Sendable (URL) async throws -> Void

  public static let live = Self { url in
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = false
    _ = try await NSWorkspace.shared.open(url, configuration: configuration)
  }

  private let openURL: OpenURL

  public init(openURL: @escaping OpenURL) {
    self.openURL = openURL
  }

  public func request(_ request: ControlActionRequest) async throws {
    try await openURL(request.url)
  }
}
```

Change `SetBatteryClamshellIntent` to:

```swift
import AppIntents
import ClamshellControlProtocol

public struct SetBatteryClamshellIntent: SetValueIntent {
  public static let title: LocalizedStringResource = "Set battery clamshell mode"
  public static let supportedModes: IntentModes = .background

  @Parameter(title: "Enabled")
  public var value: Bool

  public init() {}

  public func perform() async throws -> some IntentResult {
    let request: ControlActionRequest = value
      ? .enableBatteryClamshellMode
      : .disableBatteryClamshellMode
    try await WorkspaceControlActionRequester.live.request(request)
    return .result()
  }
}
```

In `project.yml`, make `ClamshellControlIntent` depend on
`ClamshellControlProtocol`. Remove its dependencies on `ClamshellControlModel`
and `ClamshellCore`.

Keep `BatteryClamshellControl` imports for `ClamshellControlIntent` and
`ClamshellControlModel`. Remove the old top-level intent file after the intent
framework owns its replacement.

- [ ] **Step 4: Run the control tests**

Run the `ClamshellControlTests` command from Task 1.

Expected: both requester tests and all existing control tests pass.

- [ ] **Step 5: Commit the extension relay**

```bash
git add project.yml App/ClamshellControl/Intent \
  App/ClamshellControl/BatteryClamshellControl.swift \
  App/ClamshellControlTests/SetBatteryClamshellIntentTests.swift \
  App/ClamshellControlTests/WorkspaceControlActionRequesterTests.swift
git add -u App/ClamshellControl/SetBatteryClamshellIntent.swift
git commit -m "fix(control): relay actions through the workspace"
```

## Task 3: Execute validated requests in the app

**Files:**

- Create: `App/ClamshellApp/Control/ControlActionHandler.swift`
- Create: `App/ClamshellAppTests/ControlActionHandlerTests.swift`
- Modify: `project.yml`

- [ ] **Step 1: Write handler tests before the handler**

The test suite must cover these cases with `RecordingPower` and a thread-safe
reload recorder:

```swift
@Test("applies a valid request and reloads the control")
func validRequest() throws {
  let power = RecordingPower(states: [.disabled, .enabled])
  let reloads = ReloadRecorder()
  let handler = ControlActionHandler(
    model: ControlModel(stateReader: power, stateWriter: power),
    reload: reloads.reload
  )
  let url = try #require(
    URL(string: "clamshellctl://battery-clamshell/enable")
  )

  #expect(handler.handle(url) == .applied)
  #expect(power.requestedStates == [.enabled])
  #expect(reloads.count == 1)
}

@Test("ignores an invalid request without privilege or reload")
func invalidRequest() throws {
  let power = RecordingPower(states: [.disabled])
  let reloads = ReloadRecorder()
  let handler = ControlActionHandler(
    model: ControlModel(stateReader: power, stateWriter: power),
    reload: reloads.reload
  )
  let url = try #require(URL(string: "clamshellctl://battery-clamshell/toggle"))

  #expect(handler.handle(url) == .ignored)
  #expect(power.requestedStates.isEmpty)
  #expect(reloads.count == 0)
}

@Test("reloads the actual state after a helper failure")
func helperFailure() throws {
  let power = RecordingPower(
    states: [.disabled],
    writeError: ControlActionTestError.helperFailed
  )
  let reloads = ReloadRecorder()
  let handler = ControlActionHandler(
    model: ControlModel(stateReader: power, stateWriter: power),
    reload: reloads.reload
  )
  let url = try #require(
    URL(string: "clamshellctl://battery-clamshell/enable")
  )

  #expect(handler.handle(url) == .failed)
  #expect(reloads.count == 1)
}
```

Use one private `RecordingPower` test double and one private `ReloadRecorder`
in this test file. Protect mutable recorder state with `Synchronization.Mutex`.

```swift
private enum ControlActionTestError: Error {
  case helperFailed
  case unexpectedRead
}

private final class RecordingPower: PowerStateReading, PowerStateWriting,
  @unchecked Sendable
{
  var states: [ClamshellState]
  private(set) var requestedStates: [ClamshellState] = []
  private let writeError: ControlActionTestError?

  init(
    states: [ClamshellState],
    writeError: ControlActionTestError? = nil
  ) {
    self.states = states
    self.writeError = writeError
  }

  func currentState() throws -> ClamshellState {
    guard !states.isEmpty else {
      throw ControlActionTestError.unexpectedRead
    }
    return states.removeFirst()
  }

  func setState(_ state: ClamshellState) throws {
    requestedStates.append(state)
    if let writeError {
      throw writeError
    }
  }
}

private final class ReloadRecorder: Sendable {
  private let storage = Mutex(0)

  var count: Int {
    storage.withLock { $0 }
  }

  func reload() {
    storage.withLock { $0 += 1 }
  }
}
```

The complete test file imports `ClamshellCore`, `ClamshellControlModel`,
`Foundation`, `Synchronization`, and `Testing`.

- [ ] **Step 2: Confirm the handler tests fail to compile**

Run:

```bash
xcodegen generate
xcodebuild -project Clamshell.xcodeproj -scheme ClamshellAppTests \
  -configuration Release -destination 'platform=macOS,arch=arm64' \
  CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= test
```

Expected: compilation fails because `ControlActionHandler` does not exist.

- [ ] **Step 3: Implement the handler**

```swift
import ClamshellControlModel
import ClamshellControlProtocol
import Foundation
import OSLog
import WidgetKit

struct ControlActionHandler: Sendable {
  enum Outcome: Equatable {
    case applied
    case failed
    case ignored
  }

  static let live = Self(
    model: .live,
    reload: { ControlCenter.shared.reloadAllControls() }
  )

  private let model: ControlModel
  private let reload: @Sendable () -> Void
  private let logger = Logger(
    subsystem: "uk.co.lmliam.clamshell",
    category: "control-action"
  )

  init(model: ControlModel, reload: @escaping @Sendable () -> Void) {
    self.model = model
    self.reload = reload
  }

  func handle(_ url: URL) -> Outcome {
    guard let request = ControlActionRequest(url: url) else {
      logger.error("Rejected an invalid control action URL.")
      return .ignored
    }

    defer { reload() }
    do {
      try model.setValue(request.isEnabled)
      return .applied
    } catch {
      logger.error("The control action failed: \(String(describing: error), privacy: .public)")
      return .failed
    }
  }
}
```

Add `ClamshellControlModel` and `ClamshellControlProtocol` as linked,
non-embedded dependencies of `ClamshellAppTests`.

- [ ] **Step 4: Run the app tests**

Run the command from Step 2 again.

Expected: the three handler behaviours and all existing app tests pass.

- [ ] **Step 5: Commit the app handler**

```bash
git add project.yml App/ClamshellApp/Control/ControlActionHandler.swift \
  App/ClamshellAppTests/ControlActionHandlerTests.swift
git commit -m "feat(app): handle validated control actions"
```

## Task 4: Connect macOS URL events and remove main-app intents

**Files:**

- Create: `App/ClamshellApp/Control/ControlActionApplicationDelegate.swift`
- Create: `App/ClamshellApp/Control/ApplicationLaunchPolicy.swift`
- Create: `App/ClamshellApp/Setup/SetupWindowController.swift`
- Create: `App/ClamshellAppTests/ApplicationLaunchPolicyTests.swift`
- Modify: `App/ClamshellApp/ClamshellApp.swift`
- Modify: `App/ClamshellApp/Info.plist`
- Modify: `project.yml`
- Delete: `App/ClamshellApp/ClamshellAppIntents.swift`

- [ ] **Step 1: Write the failing launch policy tests**

```swift
import AppKit
import Testing
@testable import ClamshellApp

@Suite("Application launch policy")
struct ApplicationLaunchPolicyTests {
  @Test("shows setup for a default user launch")
  func defaultLaunch() {
    let userInfo: [AnyHashable: Any] = [
      NSApplication.launchIsDefaultUserInfoKey: true
    ]

    #expect(ApplicationLaunchPolicy.shouldShowSetup(userInfo: userInfo))
  }

  @Test("does not show setup for a URL launch")
  func URLLaunch() {
    let userInfo: [AnyHashable: Any] = [
      NSApplication.launchIsDefaultUserInfoKey: false
    ]

    #expect(!ApplicationLaunchPolicy.shouldShowSetup(userInfo: userInfo))
  }

  @Test("shows setup when macOS does not provide a launch value")
  func missingLaunchValue() {
    #expect(ApplicationLaunchPolicy.shouldShowSetup(userInfo: nil))
  }
}
```

Run the `ClamshellAppTests` command from Task 3.

Expected: compilation fails because `ApplicationLaunchPolicy` does not exist.

- [ ] **Step 2: Implement the launch policy**

```swift
import AppKit

enum ApplicationLaunchPolicy {
  static func shouldShowSetup(userInfo: [AnyHashable: Any]?) -> Bool {
    userInfo?[NSApplication.launchIsDefaultUserInfoKey] as? Bool ?? true
  }
}
```

Run the `ClamshellAppTests` command again.

Expected: `ApplicationLaunchPolicyTests` passes.

- [ ] **Step 3: Register the URL scheme**

Add this value to the app `Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Viewer</string>
    <key>CFBundleURLName</key>
    <string>uk.co.lmliam.clamshell.control-action</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>clamshellctl</string>
    </array>
  </dict>
</array>
```

Mirror this declaration in the generated `info.properties` section of
`project.yml` so XcodeGen does not remove it.

```yaml
        CFBundleURLTypes:
          - CFBundleTypeRole: Viewer
            CFBundleURLName: uk.co.lmliam.clamshell.control-action
            CFBundleURLSchemes:
              - clamshellctl
```

- [ ] **Step 4: Add the optional setup window owner**

Replace the automatic SwiftUI launch window with one AppKit-owned window. This
lets the app create setup UI for a default launch and create no UI for a URL
launch.

```swift
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
```

- [ ] **Step 5: Add the Apple event adapter**

```swift
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

  func applicationWillTerminate(_ notification: Notification) {
    NSAppleEventManager.shared().removeEventHandler(
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
```

Use `@NSApplicationDelegateAdaptor` in `ClamshellApp`. A `Settings` scene keeps
the SwiftUI application lifecycle without creating a launch window:

```swift
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
```

- [ ] **Step 6: Remove App Intent registration from the main app**

Delete `App/ClamshellApp/ClamshellAppIntents.swift`. Remove the
`ClamshellControlIntent` dependency from `ClamshellApp` in `project.yml`.

Keep `ClamshellControlIntent` linked to `ClamshellControl`. This makes the
extension the only release bundle that contains the custom intent metadata.

- [ ] **Step 7: Build both release targets**

Run:

```bash
xcodegen generate
xcodebuild -project Clamshell.xcodeproj -scheme ClamshellControlTests \
  -configuration Release -destination 'platform=macOS,arch=arm64' \
  CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= test
xcodebuild -project Clamshell.xcodeproj -scheme ClamshellAppTests \
  -configuration Release -destination 'platform=macOS,arch=arm64' \
  CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= test
xcodebuild -project Clamshell.xcodeproj -scheme ClamshellApp \
  -configuration Release -destination 'platform=macOS,arch=arm64' \
  CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= build
```

Expected: both test schemes and the app build exit with status `0`.

- [ ] **Step 8: Verify the bundle boundary**

Inspect the built products with `codesign`, `plutil`, and `strings`.

Expected:

- The app and extension use ad-hoc signatures.
- Neither bundle has a Team ID.
- The app declares the `clamshellctl` URL scheme.
- The extension contains `SetBatteryClamshellIntent` metadata.
- The main app does not contain `SetBatteryClamshellIntent` metadata.

- [ ] **Step 9: Commit the lifecycle connection**

```bash
git add project.yml App/ClamshellApp/ClamshellApp.swift \
  App/ClamshellApp/Info.plist App/ClamshellApp/Control \
  App/ClamshellApp/Setup/SetupWindowController.swift \
  App/ClamshellAppTests/ApplicationLaunchPolicyTests.swift
git add -u App/ClamshellApp/ClamshellAppIntents.swift
git commit -m "fix(app): receive background control requests"
```

## Task 5: Run the local feasibility gate

**Files:**

- Modify: `docs/control-feasibility-test.md`

- [ ] **Step 1: Package and install a local test build**

Run:

```bash
swift build -c release --product clamshellctl
swift build -c release --product clamshellctl-helper
xcodebuild -project Clamshell.xcodeproj -scheme ClamshellApp \
  -configuration Release -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/feasibility/DerivedData-relay \
  CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= build
ditto \
  .build/feasibility/DerivedData-relay/Build/Products/Release/Clamshell.app \
  .build/feasibility/Clamshell-action-relay.app
install -m 0755 .build/release/clamshellctl \
  .build/feasibility/Clamshell-action-relay.app/Contents/MacOS/clamshellctl
install -m 0755 .build/release/clamshellctl-helper \
  .build/feasibility/Clamshell-action-relay.app/Contents/Resources/clamshellctl-helper
codesign --force --sign - \
  .build/feasibility/Clamshell-action-relay.app/Contents/MacOS/clamshellctl
codesign --force --sign - \
  .build/feasibility/Clamshell-action-relay.app/Contents/Resources/clamshellctl-helper
codesign --force --sign - .build/feasibility/Clamshell-action-relay.app
codesign --verify --deep --strict --verbose=2 \
  .build/feasibility/Clamshell-action-relay.app
```

Expected: each command exits with status `0`. The final verification reports a
valid nested signature.

Move the existing installed app to
`.build/feasibility/installed-pre-action-relay.app`. Do not delete it. Install
the new app with `ditto`, then run:

```bash
test -d /Applications/Clamshell.app
test ! -e .build/feasibility/installed-pre-action-relay.app
pkill -x Clamshell || true
mv /Applications/Clamshell.app \
  .build/feasibility/installed-pre-action-relay.app
ditto .build/feasibility/Clamshell-action-relay.app \
  /Applications/Clamshell.app
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
  -f /Applications/Clamshell.app
killall ControlCenter
killall chronod
```

Expected: Launch Services registers the app. Control Centre and `chronod`
restart for the current user.

- [ ] **Step 2: Confirm the precondition**

Run:

```bash
/Applications/Clamshell.app/Contents/MacOS/clamshellctl status
```

Expected: the CLI reports the same state as the Control Centre colour.

- [ ] **Step 3: Test a warm background request**

Open Clamshell, close its setup window, and keep the process running. Click the
control once.

Expected:

- The app does not activate.
- No window, Dock icon, or menu-bar item appears.
- The CLI reports the requested state.
- The control keeps the matching colour after the click highlight ends.

- [ ] **Step 4: Test a cold background request**

Terminate Clamshell and click the control once.

Expected: macOS starts Clamshell in the background, all visibility checks from
Step 3 pass, and the requested state persists.

- [ ] **Step 5: Test both directions and failure behaviour**

Test enable and disable. Then make the privileged setup unavailable without
deleting user data and click the control again.

Expected: both valid directions work. The failure leaves the `pmset` value and
control colour unchanged. No setup window opens because of a control action.

Restore the valid privileged setup after the failure check.

- [ ] **Step 6: Apply the hard decision gate**

Pass only if every warm, cold, state, and visibility check succeeds.

If macOS blocks URL delivery, rejects the extension intent, activates the app,
or shows the setup window, stop this implementation. Record the exact result,
restore the previous installed app, and write a separate local XPC relay design.
Do not add retries, cached state, or UI suppression guesses to this branch.

- [ ] **Step 7: Record the result**

Update `docs/control-feasibility-test.md` in ASD-STE100 Simplified Technical
English. Record commands, exit statuses, and non-sensitive observations. Do not
record account names, passwords, or full user paths.

- [ ] **Step 8: Commit a passing feasibility result**

Commit only if the gate passes:

```bash
git add docs/control-feasibility-test.md
git commit -m "document(control): record action relay verification"
```

If the gate fails, commit the factual failure result separately and do not open
a release PR for the relay implementation.

## Task 6: Run the complete quality gate

**Files:**

- Modify only files that a formatter changes within this plan's scope.

- [ ] **Step 1: Run repository formatting and lint checks**

Run:

```bash
swift format lint --recursive --strict Package.swift Sources Tests App
swiftlint lint --strict
```

Expected: both commands exit with status `0`.

- [ ] **Step 2: Run the complete repository check**

Run:

```bash
scripts/check.sh
```

Expected: the script exits with status `0`. Capture its final summary and exit
status before reporting success.

- [ ] **Step 3: Inspect the final diff**

Confirm that the diff contains only the approved relay, tests, project
configuration, and feasibility evidence. Confirm that `.vscode/` is untracked
and absent from every commit.

- [ ] **Step 4: Request a code review**

Request a review only after local verification passes.

- [ ] **Step 5: Open the pull request**

Use a title in `verb(area): description` form. Link the Control Centre issue and
state that the DMG remains ad-hoc signed. Include the manual warm-launch and
cold-launch results in the pull-request body.
