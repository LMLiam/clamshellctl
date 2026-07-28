# clamshellctl MVP Implementation Plan

**Goal:** Build, verify, publish, and distribute a secure Swift CLI for controlling battery clamshell mode on macOS.

**Architecture:** A pure `ClamshellCore` module owns parsing, decisions, file generation, and timer rules. Thin `ClamshellCLI` and `ClamshellHelper` executables compose those rules with Foundation-backed process and file-system adapters. Homebrew installs both products, while one explicit privileged setup command installs the immutable helper and narrow sudoers policy.

**Tech stack:** Swift 6, Swift Package Manager, Swift Testing, Apple Swift Argument Parser 1.8, macOS `pmset`, `sudo`, `launchd`, GitHub Actions, release-please v5, and Homebrew.

**Working convention:** Complete tasks in order. Develop behaviour test-first, stage explicit paths, and use `verb(area): description` commit messages. Never run privileged integration tests in CI or mutate the developer Mac unless a step is marked as a manual acceptance test.

---

## File map

The implementation uses responsibility-based files rather than grouping unrelated behaviour into large command files.

```text
Package.swift                                      SwiftPM products, targets, dependency versions
Sources/ClamshellCore/BuildVersion.swift          Release-please managed version
Sources/ClamshellCore/ClamshellState.swift        Enabled and disabled domain states
Sources/ClamshellCore/PowerSettingsParser.swift   Battery-section pmset parsing
Sources/ClamshellCore/ProcessRunner.swift          Process boundary and Foundation adapter
Sources/ClamshellCore/PowerSettingsClient.swift   Read and mutate pmset through ProcessRunner
Sources/ClamshellCore/ClamshellService.swift       Idempotent state transitions
Sources/ClamshellCore/Duration.swift               Strict m, h, and d duration parsing
Sources/ClamshellCore/TimerMetadata.swift          Codable absolute timer deadline
Sources/ClamshellCore/TimerController.swift        LaunchAgent lifecycle and expiry decisions
Sources/ClamshellCore/PrivilegedInstallation.swift Root setup and uninstall rules
Sources/ClamshellCore/SudoersPolicy.swift          Exact sudoers document generation
Sources/ClamshellCore/ClamshellError.swift         Domain errors and exit-code mapping
Sources/ClamshellCLI/ClamshellCommand.swift        Root ArgumentParser command and composition root
Sources/ClamshellCLI/Commands/*.swift              One public command per file
Sources/ClamshellCLI/Console.swift                 Quiet-aware stdout and stderr rendering
Sources/ClamshellHelper/ClamshellHelper.swift      Minimal privileged executable entry point
Tests/ClamshellCoreTests/*.swift                   Swift Testing suites by responsibility
Tests/ClamshellCLITests/*.swift                    Black-box CLI tests without privilege changes
Shortcuts/Toggle Battery Clamshell Mode.shortcut  Importable Shortcut export
scripts/generate-homebrew-formula.sh              Deterministic formula generation
scripts/validate-conventional-title.sh            Pull-request title validation
.github/workflows/ci.yml                           macOS build and test checks
.github/workflows/pr.yml                           Conventional pull-request title check
.github/workflows/release.yml                      release-please and tap publication
release-please-config.json                         Single-package release configuration
.release-please-manifest.json                      Released version manifest
version.txt                                        Simple release strategy version file
Formula/clamshellctl.rb                            Generated formula fixture for validation
docs/assets/clamshellctl.png                       Approved transparent README artwork
README.md                                          Installation, safety, use, and troubleshooting
CONTRIBUTING.md                                    Development and commit conventions
SECURITY.md                                        Privilege boundary and reporting policy
SUPPORT.md                                         Support channels and diagnostics
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

Create labels `area: cli`, `area: privilege`, `area: timer`, `area: shortcut`, `area: docs`, `area: release`, `area: homebrew`, `type: feature`, and `type: maintenance`. Create one issue for each remaining phase in this plan. Each issue body must state the end goal, acceptance criteria, owned files, dependencies, verification commands, and the corresponding plan tasks.

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
/usr/bin/sudo -n /usr/local/libexec/clamshellctl-helper enable
/usr/bin/sudo -n /usr/local/libexec/clamshellctl-helper disable
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

Accept only ASCII usernames matching `[A-Za-z0-9._-]+`. The generated policy contains exactly two non-comment command rules, one for `enable` and one for `disable`, both targeting `/usr/local/libexec/clamshellctl-helper`. Reject whitespace, path separators, shell punctuation, empty names, and newlines.

- [ ] **Step 2: Test installation operations through an injected file system**

Assert the operation order: verify root, locate payload, copy to a temporary sibling, set `root:wheel` and `0755`, atomically replace the helper, write a temporary sudoers file, set `0440`, run `/usr/sbin/visudo -cf <temporary-file>`, and atomically replace `/etc/sudoers.d/clamshellctl`. A failed `visudo` must leave the existing policy untouched.

- [ ] **Step 3: Implement setup and uninstall services**

Resolve the original user from validated `SUDO_USER`; never default to root. Locate the helper beside a development build or in Homebrew's sibling `libexec` directory. Uninstall only the two exact managed paths and remain idempotent when either is absent.

- [ ] **Step 4: Run tests without root writes**

Run: `swift test --filter SudoersPolicyTests && swift test --filter PrivilegedInstallationTests`

Expected: all tests use temporary directories and recording runners; `/usr/local/libexec` and `/etc/sudoers.d` remain unchanged.

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

## Phase 6: Shortcut and public documentation

### Task 13: Package the working Shortcut

**Files:**

- Create: `Shortcuts/Toggle Battery Clamshell Mode.shortcut`
- Create: `Shortcuts/README.md`

- [ ] **Step 1: Export the proven local Shortcut**

In Shortcuts, open `Toggle Battery Clamshell Mode`, confirm its shell action resolves `/opt/homebrew/bin/clamshellctl` first and `/usr/local/bin/clamshellctl` second, and exports a failure message if neither exists. Run `toggle --quiet`. Export the Shortcut to the exact repository path.

- [ ] **Step 2: Sign the export for sharing**

Run:

```bash
shortcuts sign \
  --mode anyone \
  --input "Shortcuts/Toggle Battery Clamshell Mode.shortcut" \
  --output "Shortcuts/Toggle Battery Clamshell Mode.signed.shortcut"
```

Replace the unsigned export with the signed output only after importing the signed copy on the same Mac and confirming it still runs. Record the import and Control Centre steps in `Shortcuts/README.md`.

- [ ] **Step 3: Verify repository safety**

Inspect the signed Shortcut in the Shortcuts app. Confirm it contains no personal paths, identifiers, secrets, unrelated actions, or network requests.

- [ ] **Step 4: Commit the Shortcut**

```bash
git add Shortcuts
git commit -m "feat(shortcut): add Control Centre toggle"
```

### Task 14: Complete user and contributor documentation

**Files:**

- Modify: `README.md`
- Create: `CONTRIBUTING.md`
- Create: `SECURITY.md`
- Create: `SUPPORT.md`
- Create: `.markdownlint-cli2.jsonc`

- [ ] **Step 1: Write the complete README**

Cover purpose, warning and scope, requirements, Homebrew installation, explicit sudo setup, commands, duration grammar, Shortcut import, Control Centre placement, status limitations, troubleshooting, uninstall, security design, development, licence, and acknowledgements. State that the tool changes only the Battery Power `disablesleep` value.

- [ ] **Step 2: Write maintenance policies**

`CONTRIBUTING.md` requires Swift 6, `swift format`, `swift test`, Conventional Commits, and `verb(area): description`. `SECURITY.md` explains the helper and sudoers boundary and provides private reporting instructions. `SUPPORT.md` lists safe diagnostic commands and forbids posting sudoers contents containing unexpected local customisations without review. Configure markdownlint with `MD013` disabled so prose uses semantic lines without an arbitrary rendered-width limit; keep all other default rules enabled.

- [ ] **Step 3: Check links and prose**

Run: `npx --yes markdownlint-cli2 '**/*.md' '#.build'`

Expected: no Markdown errors. Manually verify every relative link and ensure no internal tooling paths or process notes exist anywhere in the repository.

- [ ] **Step 4: Commit documentation**

```bash
git add .markdownlint-cli2.jsonc README.md CONTRIBUTING.md SECURITY.md SUPPORT.md docs Shortcuts/README.md
git commit -m "docs(project): document installation and maintenance"
```

## Phase 7: CI and automated releases

### Task 15: Add build, test, format, and PR-title checks

**Files:**

- Create: `.github/workflows/ci.yml`
- Create: `.github/workflows/pr.yml`
- Create: `scripts/validate-conventional-title.sh`
- Create: `Tests/Scripts/run-title-tests.sh`

- [ ] **Step 1: Test the title validator**

Accept examples such as `feat(cli): add toggle command`, `fix(timer): handle missed deadline`, and `docs(readme): clarify setup`. Reject missing scopes, uppercase verbs, empty descriptions, trailing full stops, and merge prefixes.

- [ ] **Step 2: Implement the validator**

Use a portable anchored regular expression for the allowed Conventional Commit verbs and lowercase kebab-case areas. The script accepts one title argument and prints one actionable error with valid examples.

- [ ] **Step 3: Add least-privilege workflows**

`ci.yml` runs on pushes to `main` and pull requests, uses a macOS runner, checks out pinned action SHAs, runs `swift package resolve`, `swift format lint --recursive --strict .`, `swift test`, and `swift build -c release`. It grants `contents: read` only.

`pr.yml` validates the pull-request title without checking out or executing pull-request code. It grants `pull-requests: read` only.

- [ ] **Step 4: Verify locally and with actionlint**

Run:

```bash
bash Tests/Scripts/run-title-tests.sh
swift format lint --recursive --strict .
swift test
actionlint
```

Install `actionlint` with `brew install actionlint` first when it is not already available. Expected: all local checks pass.

- [ ] **Step 5: Commit CI**

```bash
git add .github/workflows scripts Tests/Scripts
git commit -m "ci(checks): verify Swift and pull-request quality"
```

### Task 16: Configure release-please

**Files:**

- Create: `release-please-config.json`
- Create: `.release-please-manifest.json`
- Create: `CHANGELOG.md`
- Create: `.github/workflows/release.yml`
- Modify: `Sources/ClamshellCore/BuildVersion.swift`

- [ ] **Step 1: Add manifest configuration**

Use `release-type: simple`, root package `.`, `include-v-in-tag: true`, `include-component-in-tag: false`, `bump-minor-pre-major: true`, and `bump-patch-for-minor-pre-major: false`. Configure the generic updater for `Sources/ClamshellCore/BuildVersion.swift`. Use the agreed visible changelog sections and hide tests and routine chores.

Initial manifest content is `{}` and the root package sets `initial-version: "0.1.0"`; the first release PR therefore targets `0.1.0`. `version.txt` starts at `0.1.0` and must remain identical to `BuildVersion.current`. The consistency script compares the manifest only after release-please has recorded a root version.

- [ ] **Step 2: Add configuration validation**

Run release-please in dry-run mode against the local configuration and assert the schema accepts every property. Add a test script that extracts `version.txt`, the Swift version literal, and the manifest version when applicable and reports mismatches.

- [ ] **Step 3: Add the release job**

Mirror Kotventure's least-privilege pattern: top-level `permissions: {}`, job-scoped `contents: write`, `issues: write`, and `pull-requests: write`, ten-minute timeout, concurrency by workflow and ref, and release-please v5 pinned to the currently approved commit SHA. Use `${{ secrets.RELEASE_PLEASE_TOKEN || secrets.GITHUB_TOKEN }}`.

- [ ] **Step 4: Verify and commit**

Run: `actionlint && bash scripts/check-version-consistency.sh`

Expected: both checks pass.

```bash
git add .github/workflows/release.yml release-please-config.json .release-please-manifest.json CHANGELOG.md version.txt Sources/ClamshellCore/BuildVersion.swift scripts/check-version-consistency.sh
git commit -m "ci(release): automate version pull requests"
```

## Phase 8: Homebrew publication

### Task 17: Generate and test the Homebrew formula

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

### Task 18: Publish formula updates after releases

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

## Phase 9: End-to-end verification and launch

### Task 19: Run the privileged acceptance matrix

**Files:**

- Create: `docs/acceptance-test.md`

- [ ] **Step 1: Capture the starting state**

Record `pmset -g custom`, current power source, CLI version, helper ownership, and sudoers validation. Do not include machine serial numbers or unrelated system data.

- [ ] **Step 2: Install through the local formula and set up once**

Run the formula build, then the explicit setup command. Verify `root:wheel` ownership, modes `0755` and `0440`, `visudo -cf`, and that sudoers exposes only exact helper enable and disable commands.

- [ ] **Step 3: Exercise behaviour on battery and AC**

Verify status, enable, repeated enable, toggle, disable, repeated disable, quiet output, malformed duration rejection, timer replacement, automatic disable, missed-deadline recovery after sleep, Shortcut toggle, and Control Centre invocation. Confirm the AC Power section remains byte-for-byte unchanged across every mutation.

- [ ] **Step 4: Verify removal and recovery**

Run uninstall twice, confirm both managed privileged files are absent, confirm state commands provide setup guidance, reinstall, and restore battery clamshell mode to disabled at the end.

- [ ] **Step 5: Record results and commit the checklist**

Document commands and pass/fail outcomes without local secrets.

```bash
git add docs/acceptance-test.md
git commit -m "test(acceptance): verify macOS clamshell lifecycle"
```

### Task 20: Harden repository settings and perform the first release

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

- [ ] **Step 5: Update the GitHub profile repository**

Add `clamshellctl` to `LMLiam/LMLiam` using the released repository URL, a one-sentence description, and the project logo or existing profile-card style. Validate Markdown rendering, commit as `docs(profile): feature clamshellctl`, and push the profile repository separately.

- [ ] **Step 6: Mark the MVP complete**

Close the launch milestone only after the GitHub Release, Homebrew installation, Shortcut, profile link, and acceptance record are all verified. Create separate backlog issues for USB-C disconnect automation and any future native Control Widget; do not fold them into v1.

## Final verification gate

Before declaring the MVP complete, run:

```bash
swift format lint --recursive --strict .
swift test
swift build -c release
actionlint
bash scripts/check-version-consistency.sh
bash Tests/Scripts/run-title-tests.sh
bash Tests/Scripts/run-formula-generator-tests.sh
bash Tests/Scripts/run-publish-formula-tests.sh
git diff --check
git status --short
```

Expected: every command exits zero and `git status --short` prints nothing. Then repeat the public Homebrew smoke test and confirm `pmset -g custom` shows battery clamshell mode disabled and an unchanged AC Power section.
