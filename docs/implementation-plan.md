# clamshellctl MVP Implementation Plan

**Goal:** Build, verify, publish, and distribute a secure Swift CLI plus an optional self-contained macOS Control Centre companion for controlling battery clamshell mode.

**Architecture:** A pure `ClamshellCore` module owns parsing, decisions, file generation, timer rules, and the narrow helper client. Thin CLI, helper, app, and WidgetKit control targets compose those rules with Foundation-backed platform adapters. Homebrew installs the CLI path; an ad-hoc-signed DMG packages the app, control extension, CLI, and helper payload without requiring Homebrew.

**Tech stack:** Swift 6.3, Swift Package Manager, Swift Testing, SwiftUI, WidgetKit, App Intents, XcodeGen, Apple Swift Argument Parser 1.8, macOS `pmset`, `sudo`, `launchd`, GitHub Actions, release-please v5, Homebrew, and `hdiutil`.

**Working convention:** Complete tasks in order. Develop behaviour test-first, stage explicit paths, and use `verb(area): description` commit messages. Never run privileged integration tests in CI or mutate the developer Mac unless a step is marked as a manual acceptance test.

---

## File map

The implementation uses responsibility-based files rather than grouping unrelated behaviour into large command files.

```text
Package.swift                                      SwiftPM products, targets, dependency versions
Sources/ClamshellCore/BuildVersion.swift           Release-please-managed version
Sources/ClamshellCore/Errors/*.swift               Domain errors and user-facing recovery
Sources/ClamshellCore/Power/*.swift                pmset parsing, reads, writes, and helper arguments
Sources/ClamshellCore/Privilege/*.swift            Helper client, paths, and sudoers policy
Sources/ClamshellCore/Privilege/Installation/*.swift Root setup, verification, and removal
Sources/ClamshellCore/Process/*.swift              Process values, protocol, and Foundation adapter
Sources/ClamshellCore/State/*.swift                State contracts and idempotent transitions
Sources/ClamshellCore/Timing/*.swift               Duration and LaunchAgent lifecycle added in Phase 4
Sources/ClamshellCLI/ClamshellCommand.swift        Root ArgumentParser command and composition root
Sources/ClamshellCLI/Commands/*.swift              One public command per file
Sources/ClamshellCLI/CommandComposition.swift      Production dependency composition
Sources/ClamshellCLI/Console.swift                 Quiet-aware stdout and stderr rendering
Sources/ClamshellCLI/OutputOptions.swift           Shared command output flags
Sources/ClamshellHelper/ClamshellHelper.swift      Minimal privileged executable entry point
App/ClamshellApp/ClamshellApp.swift               Setup-only SwiftUI application entry point
App/ClamshellApp/SetupView.swift                  First-run, diagnostics, and removal interface
App/ClamshellApp/SetupModel.swift                 Testable companion setup state and actions
App/ClamshellApp/Info.plist                       Background-style app bundle metadata
App/ClamshellControl/ClamshellControlBundle.swift WidgetKit extension entry point
App/ClamshellControl/BatteryClamshellControl.swift Stateful Control Centre toggle
App/ClamshellControl/SetBatteryClamshellIntent.swift Exact-state App Intent action
App/ClamshellControl/Info.plist                    WidgetKit extension metadata
App/ClamshellAppTests/*.swift                     Companion model tests
App/ClamshellControlTests/*.swift                 Control model tests
Tests/ClamshellCoreTests/{Power,Privilege,Process,State}/*.swift Domain suites
Tests/ClamshellCoreTests/Support/*.swift           Shared test support by responsibility
Tests/ClamshellCLITests/Commands/*.swift           Black-box CLI tests without privilege changes
project.yml                                        Deterministic XcodeGen app project definition
scripts/embed-command-products.sh                 Bundle release CLI and helper payloads
scripts/package-dmg.sh                             Build the ad-hoc-signed release DMG
Tests/Scripts/run-dmg-packaging-tests.sh           DMG structure and input validation tests
scripts/generate-homebrew-formula.sh              Deterministic formula generation
scripts/check-conventional-subject.sh              Commit and pull-request title validation
scripts/check.sh                                   Complete local quality gate
.github/workflows/ci.yml                           macOS build and test checks
.github/workflows/pr.yml                           Conventional pull-request title check
.github/workflows/release.yml                      release-please and tap publication
release-please-config.json                         Single-package release configuration
.release-please-manifest.json                      Released version manifest
version.txt                                        Simple release strategy version file
Formula/clamshellctl.rb                            Generated formula fixture for validation
docs/assets/clamshellctl.png                       Approved transparent README artwork
README.md                                          Installation, safety, use, and troubleshooting
.github/CONTRIBUTING.md                            Development and commit conventions
.github/SECURITY.md                                Privilege boundary and reporting policy
.github/SUPPORT.md                                 Support channels and diagnostics
LICENSE                                            MIT licence
```

## Phase 1: Repository and package foundation

### Task 1: Create the Swift package skeleton

**Files:**

- Create: `Package.swift`
- Create: `Sources/ClamshellCore/BuildVersion.swift`
- Create: `Sources/ClamshellCLI/ClamshellCommand.swift`
- Create: `Sources/ClamshellHelper/ClamshellHelper.swift`
- Create: `Tests/ClamshellCoreTests/BuildVersionTests.swift`
- Create: `.gitignore`
- Create: `version.txt`

- [ ] **Step 1: Add a failing version test**

```swift
import Testing
@testable import ClamshellCore

@Suite("Build version")
struct BuildVersionTests {
    @Test("starts at the planned initial version")
    func initialVersion() {
        #expect(BuildVersion.current == "0.1.0")
    }
}
```

- [ ] **Step 2: Add the SwiftPM manifest**

```swift
// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "clamshellctl",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "clamshellctl", targets: ["ClamshellCLI"]),
        .executable(name: "clamshellctl-helper", targets: ["ClamshellHelper"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-argument-parser",
            from: "1.8.0"
        ),
    ],
    targets: [
        .target(name: "ClamshellCore"),
        .executableTarget(
            name: "ClamshellCLI",
            dependencies: [
                "ClamshellCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .executableTarget(
            name: "ClamshellHelper",
            dependencies: ["ClamshellCore"]
        ),
        .testTarget(name: "ClamshellCoreTests", dependencies: ["ClamshellCore"]),
        .testTarget(
            name: "ClamshellCLITests",
            dependencies: ["ClamshellCore"]
        ),
    ]
)
```

- [ ] **Step 3: Run the test and confirm the missing symbol**

Run: `swift test --filter BuildVersionTests`

Expected: compilation fails because `BuildVersion` does not exist.

- [ ] **Step 4: Add the initial version and executable entry points**

```swift
// Sources/ClamshellCore/BuildVersion.swift
public enum BuildVersion {
    // x-release-please-version
    public static let current = "0.1.0"
}
```

```swift
// Sources/ClamshellCLI/ClamshellCommand.swift
import ArgumentParser
import ClamshellCore

@main
struct ClamshellCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "clamshellctl",
        abstract: "Control battery clamshell mode on macOS.",
        version: BuildVersion.current
    )
}
```

```swift
// Sources/ClamshellHelper/ClamshellHelper.swift
import Foundation

@main
enum ClamshellHelper {
    static func main() {
        FileHandle.standardError.write(Data("Invalid helper invocation.\n".utf8))
        Foundation.exit(64)
    }
}
```

Write `0.1.0` followed by a newline to `version.txt`. Ignore `.build/`, `.swiftpm/`, `.DS_Store`, and `xcuserdata/` in `.gitignore`.

- [ ] **Step 5: Verify the package**

Run: `swift test && swift build -c release && swift run clamshellctl --version`

Expected: tests and release build pass; the version command prints `0.1.0`.

- [ ] **Step 6: Commit the foundation**

```bash
git add .gitignore Package.swift Sources Tests version.txt Package.resolved
git commit -m "build(package): initialise Swift command package"
```

### Task 2: Publish the repository shell and initial issues

**Files:**

- Create: `LICENSE`
- Create: `docs/assets/clamshellctl.png`
- Create: `README.md`
- Create: `.github/ISSUE_TEMPLATE/bug.yml`
- Create: `.github/ISSUE_TEMPLATE/feature.yml`

- [ ] **Step 1: Copy the approved logo and add the MIT licence**

Copy the validated transparent asset from the prototype into `docs/assets/clamshellctl.png`. Use Liam's GitHub identity and 2026 in the standard MIT licence text.

- [ ] **Step 2: Add a truthful pre-release README**

The README must show the logo, identify the project as under active development, describe the intended safety boundary, and avoid publishing installation commands until the formula exists. It must link to `docs/clamshellctl-design.md` for the detailed design.

- [ ] **Step 3: Add focused issue forms**

The bug form requests macOS version, Mac model, installation method, `clamshellctl --version`, `clamshellctl status`, expected behaviour, and actual behaviour. The feature form asks for the user problem, desired outcome, alternatives, and security or privilege impact.

- [ ] **Step 4: Commit the public repository shell**

```bash
git add LICENSE README.md docs/assets .github/ISSUE_TEMPLATE
git commit -m "docs(project): add public repository foundation"
```

- [ ] **Step 5: Create and push the public GitHub repository**

Run:

```bash
gh repo create LMLiam/clamshellctl \
  --public \
  --description "Control battery clamshell mode on macOS" \
  --source . \
  --remote origin \
  --push
```

Expected: `main` tracks `origin/main`, the repository is public, and the design and implementation plan are visible under `docs/` without internal tooling paths or process notes.

- [ ] **Step 6: Create issue labels and issue-ready milestones**

Create labels `area: cli`, `area: privilege`, `area: timer`, `area: app`, `area: control`, `area: dmg`, `area: docs`, `area: release`, `area: homebrew`, `type: feature`, and `type: maintenance`. Create one issue for each remaining phase in this plan. Each issue body must state the end goal, acceptance criteria, owned files, dependencies, verification commands, and the corresponding plan tasks.

## Phase 2: Read-only state support

### Task 3: Parse the Battery Power section safely

**Files:**

- Create: `Sources/ClamshellCore/ClamshellState.swift`
- Create: `Sources/ClamshellCore/PowerSettingsParser.swift`
- Create: `Sources/ClamshellCore/ClamshellError.swift`
- Create: `Tests/ClamshellCoreTests/PowerSettingsParserTests.swift`

- [ ] **Step 1: Add parameterised parser tests**

Use real-shaped fixtures that prove:

```swift
import Testing
@testable import ClamshellCore

@Suite("pmset parser")
struct PowerSettingsParserTests {
    @Test("reads enabled from Battery Power")
    func enabled() throws {
        let output = """
        Battery Power:
         sleep                1
         disablesleep         1
        AC Power:
         sleep                1
         disablesleep         0
        """
        #expect(try PowerSettingsParser().batteryState(from: output) == .enabled)
    }

    @Test("treats an absent battery disablesleep key as disabled")
    func absentMeansDisabled() throws {
        let output = """
        Battery Power:
         sleep                1
        AC Power:
         disablesleep         1
        """
        #expect(try PowerSettingsParser().batteryState(from: output) == .disabled)
    }

    @Test("rejects output without a Battery Power section")
    func missingBatterySection() {
        #expect(throws: ClamshellError.self) {
            try PowerSettingsParser().batteryState(from: "AC Power:\n sleep 1")
        }
    }
}
```

- [ ] **Step 2: Run the tests and confirm missing types**

Run: `swift test --filter PowerSettingsParserTests`

Expected: compilation fails for the undefined state, parser, and error types.

- [ ] **Step 3: Implement the minimal parser**

Define `public enum ClamshellState: String, Sendable { case enabled, disabled }`. Split output into trimmed lines, locate `Battery Power:`, stop at the next non-indented section heading, and inspect only an exact `disablesleep` key. Accept values `1` and `0`; throw `ClamshellError.unrecognisedPowerSettings` for other values or a missing Battery Power section.

- [ ] **Step 4: Verify parser behaviour**

Run: `swift test --filter PowerSettingsParserTests`

Expected: all parser tests pass, including AC/Battery separation and malformed output.

- [ ] **Step 5: Commit the parser**

```bash
git add Sources/ClamshellCore Tests/ClamshellCoreTests
git commit -m "feat(state): parse battery clamshell setting"
```

### Task 4: Add the process boundary and status command

**Files:**

- Create: `Sources/ClamshellCore/ProcessRunner.swift`
- Create: `Sources/ClamshellCore/PowerSettingsClient.swift`
- Create: `Sources/ClamshellCLI/Console.swift`
- Create: `Sources/ClamshellCLI/Commands/StatusCommand.swift`
- Modify: `Sources/ClamshellCLI/ClamshellCommand.swift`
- Create: `Tests/ClamshellCoreTests/PowerSettingsClientTests.swift`

- [ ] **Step 1: Test the read-only client with a recording runner**

Define a test runner returning a configured `ProcessResult`. Assert that `currentState()` calls `/usr/bin/pmset` with `[-g, custom]`, returns `.enabled` for valid output, and maps non-zero termination to `ClamshellError.processFailed` with captured stderr.

- [ ] **Step 2: Run the tests and confirm the missing process API**

Run: `swift test --filter PowerSettingsClientTests`

Expected: compilation fails for `ProcessRunning`, `ProcessResult`, and `PowerSettingsClient`.

- [ ] **Step 3: Implement the process API**

```swift
public struct ProcessResult: Sendable, Equatable {
    public let standardOutput: String
    public let standardError: String
    public let terminationStatus: Int32
}

public protocol ProcessRunning: Sendable {
    func run(_ executable: String, arguments: [String]) throws -> ProcessResult
}
```

`FoundationProcessRunner` uses `Process`, separate stdout and stderr pipes, absolute executable paths, and UTF-8 decoding with an explicit decoding error. `PowerSettingsClient.currentState()` calls only `/usr/bin/pmset -g custom` and delegates parsing.

- [ ] **Step 4: Add `status` composition**

Register `StatusCommand` as the default subcommand. It constructs `PowerSettingsClient(runner: FoundationProcessRunner())`, prints `Battery clamshell mode: <state>`, and never invokes `sudo` or `pmset` mutation arguments.

- [ ] **Step 5: Verify without mutating power settings**

Run: `swift test && swift run clamshellctl status`

Expected: tests pass and status reports the observed battery state.

- [ ] **Step 6: Commit status support**

```bash
git add Sources Tests
git commit -m "feat(status): report battery clamshell state"
```

## Phase 3: Secure state mutation

### Task 5: Implement idempotent state transitions

**Files:**

- Create: `Sources/ClamshellCore/ClamshellService.swift`
- Create: `Tests/ClamshellCoreTests/ClamshellServiceTests.swift`

- [ ] **Step 1: Test the transition matrix**

For every requested/current pair, assert the expected decision:

```swift
@Test(arguments: [
    (ClamshellState.disabled, ClamshellState.disabled, false),
    (.disabled, .enabled, true),
    (.enabled, .enabled, false),
    (.enabled, .disabled, true),
])
func transition(
    current: ClamshellState,
    requested: ClamshellState,
    shouldMutate: Bool
) throws {
    let power = RecordingPowerSettings(current: current)
    let service = ClamshellService(stateReader: power, stateWriter: power)
    let result = try service.set(requested)
    #expect(result.didChange == shouldMutate)
    #expect(power.requestedStates == (shouldMutate ? [requested] : []))
}
```

Add a verification test in which the fake reports the wrong final state and the service throws `stateVerificationFailed`.

- [ ] **Step 2: Implement the smallest service API**

`PowerStateReading` exposes `currentState()` and `PowerStateWriting` exposes `setState(_:)`. `ClamshellService` receives the two capabilities separately, reads through the former, and mutates through the latter. `set(_:)` skips an equal state, requests a change, reads again, and returns `TransitionResult(previous:current:didChange:)` only after verification. `toggle()` derives the opposite requested state from a fresh read. A single recording fake can conform to both protocols in tests; production CLI composition uses separate reader and writer implementations.

- [ ] **Step 3: Run and commit**

Run: `swift test --filter ClamshellServiceTests`

Expected: all transition and verification tests pass.

```bash
git add Sources/ClamshellCore Tests/ClamshellCoreTests
git commit -m "feat(control): add verified state transitions"
```

### Task 6: Implement the restricted privileged helper

**Files:**

- Modify: `Sources/ClamshellCore/PowerSettingsClient.swift`
- Replace: `Sources/ClamshellHelper/ClamshellHelper.swift`
- Create: `Tests/ClamshellCoreTests/PowerMutationTests.swift`

- [ ] **Step 1: Test the exact helper argument grammar**

Define `PowerMutation(rawArguments:)` and prove that only `["enable"]` and `["disable"]` are accepted. Empty input, extra arguments, flags, mixed case, and arbitrary `pmset` values must throw `invalidHelperArguments`.

- [ ] **Step 2: Add controlled mutation to `PowerSettingsClient`**

Map `.enabled` exclusively to `/usr/bin/pmset -b disablesleep 1` and `.disabled` exclusively to `/usr/bin/pmset -b disablesleep 0`. Verify through the existing read path after a zero exit status.

- [ ] **Step 3: Replace the helper entry point**

The helper must:

1. require effective UID zero;
2. parse exactly one mutation argument;
3. run the controlled mutation;
4. verify the final state;
5. print nothing on success; and
6. write a sanitised error to stderr and exit non-zero on failure.

It must not use ArgumentParser, shell execution, relative executable paths, or environment-provided command paths.

- [ ] **Step 4: Verify safely**

Run: `swift test --filter PowerMutationTests && swift build -c release`

Then run the helper without `sudo`:

```bash
.build/release/clamshellctl-helper enable
```

Expected: it exits non-zero with an administrator-privilege error before invoking `pmset`.

- [ ] **Step 5: Commit the helper**

```bash
git add Sources/ClamshellCore Sources/ClamshellHelper Tests/ClamshellCoreTests
git commit -m "feat(helper): restrict privileged power mutations"
```

### Task 7: Add enable, disable, toggle, and quiet output

**Files:**

- Create: `Sources/ClamshellCore/PrivilegedHelperClient.swift`
- Create: `Sources/ClamshellCLI/Commands/EnableCommand.swift`
- Create: `Sources/ClamshellCLI/Commands/DisableCommand.swift`
- Create: `Sources/ClamshellCLI/Commands/ToggleCommand.swift`
- Modify: `Sources/ClamshellCLI/ClamshellCommand.swift`
- Modify: `Sources/ClamshellCLI/Console.swift`
- Create: `Tests/ClamshellCoreTests/PrivilegedHelperClientTests.swift`

- [ ] **Step 1: Test exact sudo invocations**

Assert that the client runs only:

```text
/usr/bin/sudo -n /Library/PrivilegedHelperTools/clamshellctl-helper enable
/usr/bin/sudo -n /Library/PrivilegedHelperTools/clamshellctl-helper disable
```

Map sudo's non-zero result to an error that names the setup command without echoing arbitrary stderr.

- [ ] **Step 2: Implement the client and command composition**

Each public mutation command composes a read-only `PowerSettingsClient` with `PrivilegedHelperClient` through `ClamshellService`. `--quiet` is a shared `@OptionGroup`; it suppresses only successful output. Normal output distinguishes `already enabled`, `enabled`, `already disabled`, `disabled`, and the verified toggle result.

- [ ] **Step 3: Verify help and failure safety**

Run:

```bash
swift test
swift run clamshellctl --help
swift run clamshellctl enable
```

Expected: tests pass, help lists the four state commands, and enable fails with setup guidance when the project helper is not installed. It must not prompt for a password because runtime sudo uses `-n`.

- [ ] **Step 4: Commit public mutations**

```bash
git add Sources Tests
git commit -m "feat(cli): add clamshell control commands"
```

## Phase 4: Privileged installation lifecycle

### Task 8: Generate and validate the sudoers policy

**Files:**

- Create: `Sources/ClamshellCore/SudoersPolicy.swift`
- Create: `Sources/ClamshellCore/PrivilegedInstallation.swift`
- Create: `Tests/ClamshellCoreTests/SudoersPolicyTests.swift`
- Create: `Tests/ClamshellCoreTests/PrivilegedInstallationTests.swift`

- [ ] **Step 1: Test username validation and exact policy text**

Accept only ASCII usernames matching `[A-Za-z0-9._-]+`. The generated policy contains exactly two non-comment command rules, one for `enable` and one for `disable`, both targeting `/Library/PrivilegedHelperTools/clamshellctl-helper`. Reject whitespace, path separators, shell punctuation, empty names, and newlines.

- [ ] **Step 2: Test installation operations through an injected file system**

Assert the operation order: verify root, locate payload, copy to a temporary sibling, set `root:wheel` and `0755`, atomically replace the helper, write a temporary sudoers file, set `0440`, run `/usr/sbin/visudo -cf <temporary-file>`, and atomically replace `/etc/sudoers.d/clamshellctl`. A failed `visudo` must leave the existing policy untouched.

- [ ] **Step 3: Implement setup and uninstall services**

Resolve the original user from validated `SUDO_USER`; never default to root. Locate the helper beside a development build or in Homebrew's sibling `libexec` directory. Uninstall only the two exact managed paths and remain idempotent when either is absent.

- [ ] **Step 4: Run tests without root writes**

Run: `swift test --filter SudoersPolicyTests && swift test --filter PrivilegedInstallationTests`

Expected: all tests use temporary directories and recording runners; `/Library/PrivilegedHelperTools` and `/etc/sudoers.d` remain unchanged.

- [ ] **Step 5: Commit installation services**

```bash
git add Sources/ClamshellCore Tests/ClamshellCoreTests
git commit -m "feat(setup): define secure helper installation"
```

### Task 9: Expose setup and uninstall commands

**Files:**

- Create: `Sources/ClamshellCLI/Commands/SetupCommand.swift`
- Create: `Sources/ClamshellCLI/Commands/UninstallCommand.swift`
- Modify: `Sources/ClamshellCLI/ClamshellCommand.swift`
- Create: `Tests/ClamshellCLITests/SetupCommandTests.swift`

- [ ] **Step 1: Add black-box argument tests**

Test that setup and uninstall reject execution without effective UID zero, show the explicit `sudo "$(brew --prefix)/bin/clamshellctl" setup` guidance, and never attempt partial installation.

- [ ] **Step 2: Register the commands**

The commands call `PrivilegedInstallation`, print the installed or removed paths, and provide an idempotent `already configured` or `already removed` result. Setup performs a final `visudo -cf /etc/sudoers.d/clamshellctl` and helper ownership check.

- [ ] **Step 3: Verify without sudo**

Run: `swift test && swift run clamshellctl setup`

Expected: tests pass; the local command exits non-zero with explicit sudo guidance and makes no protected writes.

- [ ] **Step 4: Commit lifecycle commands**

```bash
git add Sources/ClamshellCLI Tests/ClamshellCLITests
git commit -m "feat(setup): add helper setup and removal commands"
```

## Phase 5: Timed enablement

### Task 10: Parse bounded durations and timer metadata

**Files:**

- Create: `Sources/ClamshellCore/Duration.swift`
- Create: `Sources/ClamshellCore/TimerMetadata.swift`
- Create: `Tests/ClamshellCoreTests/DurationTests.swift`
- Create: `Tests/ClamshellCoreTests/TimerMetadataTests.swift`

- [ ] **Step 1: Add strict duration tests**

Accept `1m`, `30m`, `1h`, `2h`, and `1d`. Reject zero, negative signs, decimals, spaces, missing units, uppercase units, overflow, and values longer than 30 days. Convert through checked integer arithmetic.

- [ ] **Step 2: Add metadata round-trip tests**

`TimerMetadata` contains schema version `1`, an absolute UTC deadline, and the absolute CLI executable path. Encode with stable sorted JSON keys and ISO-8601 dates. Reject unknown schema versions and non-absolute executable paths.

- [ ] **Step 3: Implement and verify**

Run: `swift test --filter DurationTests && swift test --filter TimerMetadataTests`

Expected: all accepted, rejected, and round-trip cases pass.

- [ ] **Step 4: Commit timer values**

```bash
git add Sources/ClamshellCore Tests/ClamshellCoreTests
git commit -m "feat(timer): model bounded disable deadlines"
```

### Task 11: Manage the one-shot LaunchAgent

**Files:**

- Create: `Sources/ClamshellCore/TimerController.swift`
- Create: `Tests/ClamshellCoreTests/TimerControllerTests.swift`

- [ ] **Step 1: Test LaunchAgent generation and lifecycle**

Assert that the generated plist:

- uses label `io.github.lmliam.clamshellctl.timer`;
- runs the absolute CLI path with hidden `timer-check`;
- enables `RunAtLoad` to reconcile a missed deadline after login or reboot;
- schedules `StartCalendarInterval` for the absolute deadline;
- contains no shell command or user-controlled plist key; and
- is written atomically beneath `~/Library/LaunchAgents`.

Test replacement unloads the previous agent before writing and bootstrapping the new one. Cancellation bootouts the label and deletes only the managed plist and metadata.

- [ ] **Step 2: Implement the controller**

Use `/bin/launchctl bootout gui/<uid> <plist>` and `/bin/launchctl bootstrap gui/<uid> <plist>` through `ProcessRunning`. `timer-check` reads metadata: it exits successfully without mutation before the deadline; at or after the deadline it requests disable, then cancels timer files after verified success.

- [ ] **Step 3: Verify with fakes**

Run: `swift test --filter TimerControllerTests`

Expected: tests cover create, replace, cancel, pre-deadline check, expired check, missed-deadline login, and cleanup failure without touching the real LaunchAgents directory.

- [ ] **Step 4: Commit the timer controller**

```bash
git add Sources/ClamshellCore Tests/ClamshellCoreTests
git commit -m "feat(timer): schedule verified automatic disable"
```

### Task 12: Connect timed enablement to the CLI

**Files:**

- Modify: `Sources/ClamshellCLI/Commands/EnableCommand.swift`
- Modify: `Sources/ClamshellCLI/Commands/DisableCommand.swift`
- Create: `Sources/ClamshellCLI/Commands/TimerCheckCommand.swift`
- Modify: `Sources/ClamshellCLI/Commands/StatusCommand.swift`
- Modify: `Sources/ClamshellCLI/ClamshellCommand.swift`
- Create: `Tests/ClamshellCLITests/TimedCommandTests.swift`

- [ ] **Step 1: Add command-level timer tests**

Prove that `enable --for 2h` enables first and then installs the timer; timer-install failure rolls the new enablement back to disabled; a successful manual disable cancels the timer; status displays an active deadline; and `timer-check` stays hidden from help.

- [ ] **Step 2: Implement the command flow**

Add optional `--for <duration>` to enable. Persist timer metadata only after verified enablement. If scheduling fails after a state change, request verified disable and report both failures if rollback also fails. Permanent `enable` cancels an old timer only after the user confirms intent through the explicit command invocation.

- [ ] **Step 3: Verify**

Run: `swift test && swift run clamshellctl enable --help`

Expected: all tests pass and help documents the strict duration grammar and 30-day maximum.

- [ ] **Step 4: Commit timed commands**

```bash
git add Sources/ClamshellCLI Tests/ClamshellCLITests
git commit -m "feat(cli): support temporary clamshell enablement"
```

## Phase 6: Native Control Centre companion

### Task 13: Generate the companion project and app shell

**Files:**

- Create: `project.yml`
- Create: `App/ClamshellApp/ClamshellApp.swift`
- Create: `App/ClamshellApp/SetupView.swift`
- Create: `App/ClamshellApp/Info.plist`
- Create: `App/ClamshellControl/ClamshellControlBundle.swift`
- Create: `App/ClamshellControl/BatteryClamshellControl.swift`
- Create: `App/ClamshellControl/SetBatteryClamshellIntent.swift`
- Create: `App/ClamshellControl/Info.plist`
- Modify: `.gitignore`

- [ ] **Step 1: Add the deterministic Xcode project definition**

Install XcodeGen with `brew install xcodegen`. Define one macOS 26 application, one embedded WidgetKit extension, and one unit-test target in `project.yml`. Link both production targets to the local `ClamshellCore` package product. Use bundle identifiers `uk.co.lmliam.clamshell` and `uk.co.lmliam.clamshell.control`, set `LSUIElement` to `true`, and use manual ad-hoc signing with no development team.

```yaml
name: Clamshell
options:
  deploymentTarget:
    macOS: "26.0"
packages:
  ClamshellKit:
    path: .
targets:
  ClamshellApp:
    type: application
    platform: macOS
    sources: [App/ClamshellApp]
    info:
      path: App/ClamshellApp/Info.plist
      properties:
        CFBundleDisplayName: Clamshell
        LSUIElement: true
    dependencies:
      - package: ClamshellKit
        product: ClamshellCore
      - target: ClamshellControl
        embed: true
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: uk.co.lmliam.clamshell
        CODE_SIGN_STYLE: Manual
        CODE_SIGN_IDENTITY: "-"
        DEVELOPMENT_TEAM: ""
        ARCHS: "arm64 x86_64"
        ONLY_ACTIVE_ARCH: NO
        MARKETING_VERSION: 0.1.0
        CURRENT_PROJECT_VERSION: 1
  ClamshellControl:
    type: app-extension
    platform: macOS
    sources: [App/ClamshellControl]
    info:
      path: App/ClamshellControl/Info.plist
      properties:
        NSExtension:
          NSExtensionPointIdentifier: com.apple.widgetkit-extension
    dependencies:
      - package: ClamshellKit
        product: ClamshellCore
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: uk.co.lmliam.clamshell.control
        CODE_SIGN_STYLE: Manual
        CODE_SIGN_IDENTITY: "-"
        DEVELOPMENT_TEAM: ""
        ARCHS: "arm64 x86_64"
        ONLY_ACTIVE_ARCH: NO
        MARKETING_VERSION: 0.1.0
        CURRENT_PROJECT_VERSION: 1
  ClamshellAppTests:
    type: bundle.unit-test
    platform: macOS
    sources: [App/ClamshellAppTests]
    dependencies:
      - target: ClamshellApp
  ClamshellControlTests:
    type: bundle.unit-test
    platform: macOS
    sources: [App/ClamshellControlTests]
    dependencies:
      - target: ClamshellControl
```

- [ ] **Step 2: Add the smallest compiling app and control**

Create an `@main` SwiftUI app with a single setup window. Create a WidgetKit `WidgetBundle` containing `BatteryClamshellControl`. Initially return `false` from the value provider and make the intent return `.result()` without mutation; this step proves project composition only.

```swift
import SwiftUI

@main
struct ClamshellApp: App {
    var body: some Scene {
        Window("Clamshell", id: "setup") {
            SetupView()
        }
    }
}

struct SetupView: View {
    var body: some View {
        Text("Clamshell setup")
            .padding()
    }
}
```

```swift
import AppIntents
import SwiftUI
import WidgetKit

@main
struct ClamshellControlBundle: WidgetBundle {
    var body: some Widget {
        BatteryClamshellControl()
    }
}

struct BatteryClamshellControl: ControlWidget {
    static let kind = "uk.co.lmliam.clamshell.control.battery"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind, provider: Provider()) {
            isEnabled in
            ControlWidgetToggle(
                "Battery Clamshell Mode",
                isOn: isEnabled,
                action: SetBatteryClamshellIntent()
            )
        }
    }

    struct Provider: ControlValueProvider {
        let previewValue = false

        func currentValue() async throws -> Bool {
            false
        }
    }
}

struct SetBatteryClamshellIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Set battery clamshell mode"

    @Parameter(title: "Enabled")
    var value: Bool

    func perform() async throws -> some IntentResult {
        .result()
    }
}
```

- [ ] **Step 3: Generate and build the app**

Run:

```bash
xcodegen generate
xcodebuild \
  -project Clamshell.xcodeproj \
  -scheme ClamshellApp \
  -configuration Debug \
  -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY=- \
  DEVELOPMENT_TEAM= \
  build
```

Expected: XcodeGen produces the project and Xcode builds an ad-hoc-signed app containing `ClamshellControl.appex`. Add `Clamshell.xcodeproj/` to `.gitignore`; `project.yml` is the source of truth.

- [ ] **Step 4: Commit the project shell**

```bash
git add .gitignore project.yml App/ClamshellApp App/ClamshellControl
git commit -m "build(app): add generated companion project"
```

### Task 14: Prove the unsigned Control Centre boundary

**Files:**

- Create: `App/ClamshellControl/ControlModel.swift`
- Create: `App/ClamshellControlTests/ControlModelTests.swift`
- Modify: `App/ClamshellControl/BatteryClamshellControl.swift`
- Modify: `App/ClamshellControl/SetBatteryClamshellIntent.swift`
- Create: `docs/control-feasibility-test.md`

- [ ] **Step 1: Test exact-state control requests**

Use fakes to prove that requesting the current state performs no mutation, requesting a different state invokes exactly one helper operation, helper failure propagates, and the final state is verified before success.

```swift
import Testing
@testable import ClamshellControl
import ClamshellCore

private final class RecordingPower: @unchecked Sendable,
    PowerStateReading, PowerStateWriting {
    var states: [ClamshellState]
    var requestedStates: [ClamshellState] = []

    init(states: [ClamshellState]) {
        self.states = states
    }

    func currentState() throws -> ClamshellState {
        states.removeFirst()
    }

    func setState(_ state: ClamshellState) throws {
        requestedStates.append(state)
    }
}

@Test("enables through the helper and verifies the result")
func enablesAndVerifies() throws {
    let power = RecordingPower(states: [.disabled, .enabled])
    let model = ControlModel(stateReader: power, stateWriter: power)

    try model.setValue(true)

    #expect(power.requestedStates == [.enabled])
    #expect(power.states.isEmpty)
}
```

- [ ] **Step 2: Run the test and confirm the missing service**

Run: `xcodebuild -project Clamshell.xcodeproj -scheme ClamshellControlTests -destination 'platform=macOS' test`

Expected: compilation fails because `ControlModel` does not exist.

- [ ] **Step 3: Implement the control model by composing the shared service**

Define `ControlModel` with injected `PowerStateReading` and `PowerStateWriting` dependencies. `currentValue()` maps `.enabled` to `true`; `setValue(_:)` maps the Boolean to `ClamshellState` and delegates to Task 5's `ClamshellService`. Production composition uses `PowerSettingsClient` for reads and `PrivilegedHelperClient` for writes, so the control reuses the same idempotency, exact sudo invocation, and final verification as the CLI.

- [ ] **Step 4: Connect the WidgetKit value and intent**

The provider calls `ControlModel.live.currentValue()`. The `SetValueIntent` calls `ControlModel.live.setValue(_:)`, declares background support, requests the value supplied by WidgetKit, and reloads the control only after verified success.

```swift
struct SetBatteryClamshellIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Set battery clamshell mode"
    static var supportedModes: IntentModes { .background }

    @Parameter(title: "Enabled")
    var value: Bool

    func perform() async throws -> some IntentResult {
        try ControlModel.live.setValue(value)
        ControlCenter.shared.reloadControls(
            ofKind: BatteryClamshellControl.kind
        )
        return .result()
    }
}
```

- [ ] **Step 5: Run the mandatory clean-account feasibility test**

Build Release with `CODE_SIGN_IDENTITY=-`, copy `Clamshell.app` to `/Applications`, trigger Gatekeeper quarantine with a locally created DMG, approve the app through Privacy & Security, and add its control to Control Centre. Verify inactive state, enable, active state, disable, state changes made through the CLI, and behaviour after replacing the app with a second ad-hoc-signed build.

Record the exact build, installation, `codesign`, `spctl`, helper, and `pmset` observations in `docs/control-feasibility-test.md`. Do not record account identifiers or passwords. If extension discovery, read-only `pmset`, helper invocation, state reconciliation, or update persistence fails, stop companion work and leave DMG publication disabled; the CLI plan continues independently.

- [ ] **Step 6: Verify and commit the proven boundary**

Run:

```bash
xcodebuild -project Clamshell.xcodeproj -scheme ClamshellControlTests -configuration Release -destination 'platform=macOS' CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= test
xcodebuild -project Clamshell.xcodeproj -scheme ClamshellApp -configuration Release -destination 'platform=macOS' CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= build
```

Expected: automated tests pass and the feasibility record contains a pass for every mandatory observation.

```bash
git add App/ClamshellControl App/ClamshellControlTests project.yml docs/control-feasibility-test.md
git commit -m "feat(control): add verified Control Centre toggle"
```

### Task 15: Add companion setup and optional CLI exposure

**Files:**

- Create: `App/ClamshellApp/SetupModel.swift`
- Create: `App/ClamshellAppTests/SetupModelTests.swift`
- Modify: `App/ClamshellApp/SetupView.swift`
- Modify: `Sources/ClamshellCore/PrivilegedInstallation.swift`
- Modify: `Sources/ClamshellCLI/Commands/SetupCommand.swift`
- Modify: `Sources/ClamshellCLI/Commands/UninstallCommand.swift`

- [ ] **Step 1: Test setup presentation states**

Test `.needsSetup`, `.ready`, `.invalidHelper`, and `.missingBundlePayload`. Prove that setup requests administrator authorisation once, CLI exposure creates only `/usr/local/bin/clamshellctl`, removal deletes the symlink only when it resolves inside `Clamshell.app`, and diagnostic refresh never mutates system state.

```swift
@Test("does not remove an unrelated command")
func preservesUnrelatedCommand() async throws {
    let fixture = SetupModelFixture(cliLinkTarget: "/tmp/not-clamshellctl")

    try await fixture.model.removePrivilegedSetup()

    #expect(fixture.files.removedPaths.contains("/usr/local/bin/clamshellctl") == false)
}
```

- [ ] **Step 2: Run the tests and confirm missing setup types**

Run:

```bash
xcodegen generate
xcodebuild -project Clamshell.xcodeproj -scheme ClamshellApp -destination 'platform=macOS' test
```

Expected: compilation fails because `SetupModel` and its injected boundaries do not exist.

- [ ] **Step 3: Implement the setup model and view**

`SetupModel` owns display state only and depends on protocols for diagnostics, administrator-authorised setup, CLI-link installation, and removal. `SetupView` shows the current helper status, an explicit **Set Up** button, an opt-in **Install terminal command** toggle, Control Centre placement instructions, and **Remove privileged components**. It never displays or stores a password.

First-run setup invokes the app-bundled `clamshellctl setup` through macOS's administrator-authorisation dialog. Resolve the app bundle before authorisation, reject a bundle outside `/Applications`, construct the command only from allowlisted arguments and shell-quoted absolute paths, and reuse Task 9's setup validation rather than duplicating file-writing rules. Never interpolate free-form user input into the authorised command.

- [ ] **Step 4: Verify setup and removal manually**

On a test account, confirm one authorisation prompt, exact helper ownership and modes, valid sudoers syntax, optional CLI symlink target, correct diagnostics after relaunch, safe repeated setup, safe repeated removal, and preservation of an unrelated `/usr/local/bin/clamshellctl` fixture.

- [ ] **Step 5: Commit companion setup**

```bash
git add App/ClamshellApp App/ClamshellAppTests Sources/ClamshellCore/PrivilegedInstallation.swift Sources/ClamshellCLI/Commands/SetupCommand.swift Sources/ClamshellCLI/Commands/UninstallCommand.swift
git commit -m "feat(app): add privileged setup experience"
```

### Task 16: Bundle command products and package the DMG

**Files:**

- Create: `scripts/embed-command-products.sh`
- Create: `scripts/package-dmg.sh`
- Create: `Tests/Scripts/run-dmg-packaging-tests.sh`
- Modify: `project.yml`

- [ ] **Step 1: Test packaging input validation**

The shell test supplies temporary fixture app bundles and proves rejection of a malformed version, missing CLI, missing helper, missing extension, non-ad-hoc nested signature, and an output path outside the supplied directory. It also proves that a valid fixture creates exactly `clamshellctl-v1.2.3.dmg` containing `Clamshell.app` and an `/Applications` symlink.

- [ ] **Step 2: Run the test and confirm the missing scripts**

Run: `bash Tests/Scripts/run-dmg-packaging-tests.sh`

Expected: failure because `scripts/package-dmg.sh` does not exist.

- [ ] **Step 3: Implement deterministic embedding and packaging**

`embed-command-products.sh` copies the universal release `clamshellctl` to `Contents/MacOS/clamshellctl` and the universal helper payload to `Contents/Resources/clamshellctl-helper`, then verifies both are executable and contain `arm64` and `x86_64` slices with `lipo -verify_arch`. `package-dmg.sh` accepts only `VERSION` and `OUTPUT_DIRECTORY`, builds SwiftPM release products for both architectures, generates the Xcode project, builds Release with `ARCHS='arm64 x86_64'`, `ONLY_ACTIVE_ARCH=NO`, and ad-hoc signing, verifies nested code with `codesign --verify --deep --strict`, stages only the app and `/Applications` symlink, creates a compressed read-only DMG with `hdiutil`, remounts it read-only, and verifies its contents before returning success.

- [ ] **Step 4: Verify the real artefact**

Run:

```bash
bash Tests/Scripts/run-dmg-packaging-tests.sh
bash scripts/package-dmg.sh 0.1.0 .build/releases
hdiutil verify .build/releases/clamshellctl-v0.1.0.dmg
spctl --assess --type open --context context:primary-signature .build/releases/clamshellctl-v0.1.0.dmg || true
```

Expected: script tests and `hdiutil` pass. `spctl` rejects the intentionally unnotarised download artefact, matching the documented Gatekeeper flow.

- [ ] **Step 5: Produce and verify the checksum**

Write `clamshellctl-v0.1.0.dmg.sha256` using `shasum -a 256`, verify it with `shasum -a 256 -c`, and assert the checksum file contains only the artefact basename rather than a local absolute path.

- [ ] **Step 6: Commit DMG packaging**

```bash
git add project.yml scripts/embed-command-products.sh scripts/package-dmg.sh Tests/Scripts/run-dmg-packaging-tests.sh
git commit -m "build(dmg): package self-contained companion"
```

## Phase 7: Public documentation

### Task 17: Complete user and contributor documentation

**Files:**

- Modify: `README.md`
- Create: `.github/CONTRIBUTING.md`
- Create: `.github/SECURITY.md`
- Create: `.github/SUPPORT.md`
- Create: `.markdownlint-cli2.jsonc`

- [ ] **Step 1: Write the complete README**

Cover purpose, warning and scope, separate Homebrew and DMG installation paths, macOS 13 CLI and macOS 26 companion requirements, explicit privileged setup, commands, duration grammar, Gatekeeper `Open Anyway`, Control Centre placement, active and inactive appearance, optional terminal command, troubleshooting, complete removal, security design, development, licence, and acknowledgements. State that the tool changes only the Battery Power `disablesleep` value and that the DMG is not notarised.

- [ ] **Step 2: Write maintenance policies**

`CONTRIBUTING.md` requires Swift 6, `scripts/check.sh`, Conventional Commits, and `verb(area): description`. `SECURITY.md` explains the helper and sudoers boundary and provides private reporting instructions. `SUPPORT.md` lists safe diagnostic commands and forbids posting sudoers contents containing unexpected local customisations without review. Configure markdownlint with `MD013` disabled so prose uses semantic lines without an arbitrary rendered-width limit; keep all other default rules enabled.

- [ ] **Step 3: Check links and prose**

Run: `scripts/check.sh && npx --yes markdownlint-cli2 '**/*.md' '#.build'`

Expected: no Markdown errors. Manually verify every relative link and ensure no internal tooling paths or process notes exist anywhere in the repository.

- [ ] **Step 4: Commit documentation**

```bash
git add .markdownlint-cli2.jsonc README.md .github docs
git commit -m "docs(project): document installation and maintenance"
```

## Phase 8: CI and automated releases

### Task 18: Add build, test, format, and PR-title checks

**Files:**

- Create: `.github/workflows/ci.yml`
- Create: `.github/workflows/pr.yml`
- Create: `scripts/check-conventional-subject.sh`

- [ ] **Step 1: Test the title validator**

Accept examples such as `feat(cli): add toggle command`, `fix(timer): handle missed deadline`, and `docs(readme): clarify setup`. Reject missing scopes, uppercase verbs, empty descriptions, trailing full stops, and merge prefixes.

- [ ] **Step 2: Implement the validator**

Use a portable anchored regular expression for the allowed Conventional Commit verbs and lowercase kebab-case areas. The script accepts one title argument and prints one actionable error with valid examples.

- [ ] **Step 3: Add least-privilege workflows**

`ci.yml` runs on pushes to `main` and pull requests, uses macOS runners, checks out pinned action SHAs, and runs formatting, SwiftLint, tests, and debug and release builds. Add XcodeGen and an unsigned `xcodebuild` when the native targets exist. It grants `contents: read` only.

`pr.yml` validates the pull-request title without checking out or executing pull-request code. It grants `pull-requests: read` only.

- [ ] **Step 4: Verify locally and with actionlint**

Run:

```bash
scripts/check-conventional-subject.sh "feat(cli): add toggle command"
! scripts/check-conventional-subject.sh "feat: add toggle command"
scripts/check.sh
```

Install `actionlint` with `brew install actionlint` first when it is not already available. Expected: all local checks pass.

- [ ] **Step 5: Commit CI**

```bash
git add .github/workflows scripts
git commit -m "ci(checks): verify Swift and pull-request quality"
```

### Task 19: Configure release-please

**Files:**

- Create: `release-please-config.json`
- Create: `.release-please-manifest.json`
- Create: `CHANGELOG.md`
- Create: `.github/workflows/release.yml`
- Modify: `Sources/ClamshellCore/BuildVersion.swift`

- [ ] **Step 1: Add manifest configuration**

Use `release-type: simple`, root package `.`, `include-v-in-tag: true`, `include-component-in-tag: false`, `bump-minor-pre-major: true`, and `bump-patch-for-minor-pre-major: false`. Configure generic updaters for `Sources/ClamshellCore/BuildVersion.swift` and both `MARKETING_VERSION` entries in `project.yml`. Use the agreed visible changelog sections and hide tests and routine chores.

Initial manifest content is `{}` and the root package sets `initial-version: "0.1.0"`; the first release PR therefore targets `0.1.0`. `version.txt` starts at `0.1.0` and must remain identical to `BuildVersion.current` and the two app `MARKETING_VERSION` values. The consistency script compares the manifest only after release-please has recorded a root version.

- [ ] **Step 2: Add configuration validation**

Run release-please in dry-run mode against the local configuration and assert the schema accepts every property. Add a test script that extracts `version.txt`, the Swift version literal, both app marketing-version values, and the manifest version when applicable and reports mismatches.

- [ ] **Step 3: Add the release job**

Mirror Kotventure's least-privilege pattern: top-level `permissions: {}`, job-scoped `contents: write`, `issues: write`, and `pull-requests: write`, ten-minute timeout, concurrency by workflow and ref, and release-please v5 pinned to the currently approved commit SHA. Use `${{ secrets.RELEASE_PLEASE_TOKEN || secrets.GITHUB_TOKEN }}`.

Expose `release_created`, `tag_name`, and `version`. When `release_created` is true, an output-gated macOS job installs XcodeGen, checks out the exact tag, runs `scripts/package-dmg.sh`, verifies the DMG and checksum, and uploads both to the existing GitHub Release. Grant only `contents: write`; do not configure signing secrets or claim notarisation.

- [ ] **Step 4: Verify and commit**

Run: `actionlint && bash scripts/check-version-consistency.sh`

Expected: both checks pass.

```bash
git add .github/workflows/release.yml release-please-config.json .release-please-manifest.json CHANGELOG.md version.txt project.yml Sources/ClamshellCore/BuildVersion.swift scripts/check-version-consistency.sh
git commit -m "ci(release): automate version pull requests"
```

## Phase 9: Homebrew publication

### Task 20: Generate and test the Homebrew formula

**Files:**

- Create: `scripts/generate-homebrew-formula.sh`
- Create: `Tests/Scripts/run-formula-generator-tests.sh`
- Create: `Formula/clamshellctl.rb`

- [ ] **Step 1: Test deterministic formula generation**

Given repository, tag, source SHA-256, and version inputs, assert exact Ruby output. Reject tags not matching `vMAJOR.MINOR.PATCH` and checksums not matching 64 lowercase hexadecimal characters.

- [ ] **Step 2: Implement the generator**

The generated formula is macOS-only, depends on a Swift-capable Xcode Command Line Tools environment at build time, builds both release products with SwiftPM, installs `clamshellctl` to `bin`, installs `clamshellctl-helper` to `libexec`, prints the explicit setup caveat, and tests only `--version`.

- [ ] **Step 3: Test a local formula build**

Run:

```bash
bash Tests/Scripts/run-formula-generator-tests.sh
brew install --build-from-source ./Formula/clamshellctl.rb
"$(brew --prefix)/bin/clamshellctl" --version
brew uninstall clamshellctl
```

Expected: the formula builds from source, reports `0.1.0`, makes no privileged changes, and uninstalls cleanly.

- [ ] **Step 4: Commit formula support**

```bash
git add Formula scripts/generate-homebrew-formula.sh Tests/Scripts
git commit -m "feat(homebrew): add source-build formula"
```

### Task 21: Publish formula updates after releases

**Files:**

- Modify: `.github/workflows/release.yml`
- Create: `scripts/publish-homebrew-formula.sh`

- [ ] **Step 1: Add an output-gated publication job**

Expose release-please's `release_created`, `tag_name`, and `version` outputs. Run the Homebrew job only when `release_created` is true. Checkout the exact tag, calculate the GitHub source archive checksum, generate the formula, validate its syntax and audit rules, and update `Formula/clamshellctl.rb` in `LMLiam/homebrew-tap`.

- [ ] **Step 2: Keep cross-repository credentials narrow**

Use only `TAP_GITHUB_TOKEN` for cloning and pushing the tap. Do not print or persist it. Commit to the tap as `LMLiam` with message `brew(clamshellctl): update to vX.Y.Z`, matching the scoped convention. Exit successfully without a commit when the formula is already current.

- [ ] **Step 3: Test publication against temporary repositories**

The script test creates local bare source and tap repositories, supplies a fixture tag and checksum, and proves first-run commit, idempotent second run, and rejection of an unexpected remote or formula path. It must not access GitHub.

- [ ] **Step 4: Verify and commit**

Run: `bash Tests/Scripts/run-publish-formula-tests.sh && actionlint`

Expected: publication fixtures and workflow lint pass.

```bash
git add .github/workflows/release.yml scripts/publish-homebrew-formula.sh Tests/Scripts
git commit -m "ci(homebrew): publish released formula to tap"
```

## Phase 10: End-to-end verification and launch

### Task 22: Run the privileged acceptance matrix

**Files:**

- Create: `docs/acceptance-test.md`

- [ ] **Step 1: Capture the starting state**

Record `pmset -g custom`, current power source, CLI version, helper ownership, and sudoers validation. Do not include machine serial numbers or unrelated system data.

- [ ] **Step 2: Install through the local formula and set up once**

Run the formula build, then the explicit setup command. Verify `root:wheel` ownership, modes `0755` and `0440`, `visudo -cf`, and that sudoers exposes only exact helper enable and disable commands.

- [ ] **Step 3: Exercise behaviour on battery and AC**

Verify status, enable, repeated enable, toggle, disable, repeated disable, quiet output, malformed duration rejection, timer replacement, automatic disable, missed-deadline recovery after sleep, Control Centre enable and disable, active and inactive rendering, and state reconciliation after CLI changes. Confirm the AC Power section remains byte-for-byte unchanged across every mutation.

- [ ] **Step 4: Verify removal and recovery**

Run uninstall twice, confirm both managed privileged files are absent, confirm state commands provide setup guidance, reinstall, and restore battery clamshell mode to disabled at the end.

- [ ] **Step 5: Record results and commit the checklist**

Document commands and pass/fail outcomes without local secrets.

```bash
git add docs/acceptance-test.md
git commit -m "test(acceptance): verify macOS clamshell lifecycle"
```

### Task 23: Harden repository settings and perform the first release

**Files:**

- Modify: `README.md`
- Modify: `LMLiam/LMLiam` profile README in its own checkout and commit

- [ ] **Step 1: Configure repository settings**

Enable issues, vulnerability reporting, default squash merging, automatic head-branch deletion, Actions permission to create pull requests, and `main` protection requiring CI and PR-title checks. Add `RELEASE_PLEASE_TOKEN` and `TAP_GITHUB_TOKEN` as repository secrets without exposing their values.

- [ ] **Step 2: Verify every issue and check**

Ensure each implementation issue contains its final approved plan, is closed by its implementation pull request, and has no unresolved acceptance criteria. Confirm the full CI suite passes on `main` and the working tree is clean.

- [ ] **Step 3: Merge the first release-please PR**

Expected results: tag `v0.1.0`, GitHub Release `v0.1.0`, updated `CHANGELOG.md`, and `Formula/clamshellctl.rb` committed to `LMLiam/homebrew-tap`.

- [ ] **Step 4: Test the public installation from scratch**

Run:

```bash
brew uninstall clamshellctl 2>/dev/null || true
brew untap LMLiam/tap 2>/dev/null || true
brew install LMLiam/tap/clamshellctl
"$(brew --prefix)/bin/clamshellctl" --version
```

Expected: Homebrew installs `0.1.0` from the public release. Perform setup, one enable/disable cycle, uninstall privileged components, and leave the machine disabled.

- [ ] **Step 5: Test the public DMG from scratch**

Download the release DMG and checksum through the public GitHub Release URL, verify `shasum -a 256 -c`, mount it, drag `Clamshell.app` to `/Applications`, and follow only the published Gatekeeper instructions. Complete setup, add the toggle to Control Centre, verify one enable and disable cycle plus active and inactive appearance, expose the optional terminal command, remove privileged components, and delete the app. Confirm no helper, sudoers rule, or CLI symlink remains.

- [ ] **Step 6: Update the GitHub profile repository**

Add `clamshellctl` to `LMLiam/LMLiam` using the released repository URL, a one-sentence description, and the project logo or existing profile-card style. Validate Markdown rendering, commit as `docs(profile): feature clamshellctl`, and push the profile repository separately.

- [ ] **Step 7: Mark the MVP complete**

Close the launch milestone only after the GitHub Release, public DMG, Homebrew installation, Control Centre companion, profile link, and acceptance record are all verified. Create a separate backlog issue for USB-C disconnect automation; do not fold it into v1.

## Final verification gate

Before declaring the MVP complete, run:

```bash
scripts/check.sh
bash scripts/check-version-consistency.sh
while IFS= read -r subject; do
  scripts/check-conventional-subject.sh "$subject"
done < <(git log --format=%s origin/main..HEAD)
bash Tests/Scripts/run-dmg-packaging-tests.sh
bash Tests/Scripts/run-formula-generator-tests.sh
bash Tests/Scripts/run-publish-formula-tests.sh
git diff --check
git status --short
```

Expected: every command exits zero and `git status --short` prints nothing. Then repeat both public installation smoke tests and confirm `pmset -g custom` shows battery clamshell mode disabled, the AC Power section is unchanged, and DMG removal leaves no helper, sudoers rule, or CLI symlink.
