# clamshellctl Design

## Summary

`clamshellctl` allows a Mac notebook to remain awake in clamshell mode while it is running on battery power. It wraps the relevant `pmset` setting behind a small, testable Swift core and a narrowly restricted privileged helper.

The CLI is the primary product and Homebrew is its default installation method. An optional, self-contained macOS companion app provides a stateful WidgetKit control that users can place in Control Centre. The companion is distributed as a GitHub Release DMG and does not require a separate Homebrew installation.

## Goals

- Provide clear `status`, `enable`, `disable`, and `toggle` commands.
- Support temporary enablement with `enable --for <duration>`.
- Require an administrator password only during initial privileged setup or removal.
- Keep password-free operation limited to the two required `pmset` mutations.
- Make repeated commands safe and idempotent.
- Provide an optional native toggle that users can add to Control Centre.
- Reflect the verified enabled state through the control's active and inactive appearance.
- Package the companion app, control extension, CLI, and helper payload together in one DMG installation.
- Keep the companion out of the Dock and menu bar during normal operation.
- Publish releases through release-please and distribute through `LMLiam/homebrew-tap`.
- Work on both Apple silicon and Intel Macs supported by the selected Swift toolchain.

## Non-goals for v1

- A persistent menu-bar application.
- A traditional desktop or Notification Centre widget.
- Apple Developer Programme signing or notarisation.
- Automatically changing the setting when USB-C devices are disconnected.
- Linux or Windows support.
- JSON output or a persistent application database.

Automatic USB-C disconnect handling remains a separate future issue because the implementation must distinguish displays and power sources from unrelated USB-C devices.

## User experience

Users choose one of two independent installation paths:

- Homebrew installs the CLI and helper payload for terminal-first use.
- The GitHub DMG installs `Clamshell.app`, which includes the Control Centre extension, the same CLI, and the helper payload.

Installing the DMG does not require Homebrew. The app's first-run setup explains the unsigned-app Gatekeeper approval, installs the root-owned helper and narrow sudoers policy after administrator authorisation, and confirms that the system can discover the Control Centre toggle. The user adds the toggle to Control Centre because macOS does not allow an app to make that personalisation choice automatically.

The app has no persistent Dock or menu-bar presence. It presents a small setup and diagnostics window when opened directly. Users who want terminal access can optionally expose the bundled CLI at `/usr/local/bin/clamshellctl`; this is a symlink to the app-bundled executable rather than a second copy.

The public command surface is:

```text
clamshellctl status
clamshellctl enable
clamshellctl enable --for 2h
clamshellctl disable
clamshellctl toggle
clamshellctl setup
clamshellctl uninstall
clamshellctl --version
clamshellctl --help
```

`status` prints either `Battery clamshell mode: enabled` or `Battery clamshell mode: disabled`. If a timer is active, it also prints the scheduled automatic-disable time.

`enable`, `disable`, and `toggle` verify the resulting system state before reporting success. Repeating `enable` when already enabled or `disable` when already disabled succeeds without an unnecessary mutation.

`--quiet` suppresses successful output for automation and scripts. Errors still go to standard error and use a non-zero exit status.

Durations accept a deliberately small syntax: whole numbers followed by `m`, `h`, or `d`, such as `30m`, `2h`, or `1d`. A new timed enable replaces an existing timer. Manual disablement cancels any active timer.

## Architecture

The repository contains a Swift package for the shared implementation and CLI products, plus an Xcode project for the native companion:

1. `ClamshellCore` owns state parsing, command decisions, duration handling, timer metadata, setup-file generation, and domain errors. It does not execute privileged system changes directly.
2. `ClamshellCLI` produces the `clamshellctl` executable. It parses arguments, reads current state, invokes the helper when needed, manages the timer, and renders user-facing output.
3. `ClamshellHelper` produces the `clamshellctl-helper` executable. It accepts only `enable` or `disable`, invokes `pmset`, and verifies the resulting state.
4. `ClamshellApp` provides first-run setup, diagnostics, and helper removal. It has no persistent Dock or menu-bar item. Normal state reads and mutations call `ClamshellCore` directly.
5. `ClamshellControl` is a WidgetKit extension that supplies a `ControlWidgetToggle`. Its value provider performs the read-only `pmset` query through `ClamshellCore`; its `SetValueIntent` uses the same narrow helper client as the app and verifies the requested state before returning.

System commands are accessed through injected process-running interfaces so unit and integration tests can use deterministic fakes. `pmset` remains the sole source of truth for whether battery clamshell mode is enabled.

The app and CLI both call `ClamshellCore`; normal app operation does not shell out through the CLI. First-run setup is the deliberate exception: the app uses the macOS administrator-authorisation dialog to run the bundled CLI's existing `setup` operation, keeping one audited privileged-installation path. The DMG bundles the CLI executable for optional terminal use and bundles the helper only as an installation payload. The privileged helper installed on the system is a root-owned copy outside the user-writable app bundle.

The CLI supports macOS 13 and later. The companion app and Control Centre extension support macOS 26 and later, which is the first macOS SDK that exposes WidgetKit controls on Mac. Keeping separate deployment targets preserves broad CLI compatibility without weakening the native experience.

The implementation favours idiomatic Swift, small responsibility-based types, explicit dependency boundaries, and value semantics where appropriate. Public and internal APIs remain easy to extend without speculative abstractions: each component exposes the smallest interface needed by its callers, while platform interactions stay behind replaceable adapters.

## State and command flow

The current battery setting is read from the Battery Power section of `/usr/bin/pmset -g custom`. No cached copy is used to answer `status` or decide `toggle`.

For a mutation:

1. The CLI reads the current state.
2. It returns successfully if the requested state is already active.
3. Otherwise it runs the root-owned helper through password-free, non-interactive `sudo`.
4. The helper validates its exact argument and runs `/usr/bin/pmset -b disablesleep 1` or `/usr/bin/pmset -b disablesleep 0`.
5. The helper re-reads the setting and fails if the expected state was not applied.
6. The CLI performs its own final read and reports the verified result.

This flow keeps normal operation fast while preventing a successful message from being printed when the setting did not change.

## Privileged setup and removal

Homebrew installs the public CLI and an unprivileged helper payload. The companion app contains equivalent payloads inside its bundle. Neither installation path performs privileged changes before the user explicitly starts setup.

The documented setup command runs the installed CLI with `sudo`, using its explicit Homebrew path where the administrator's secure path does not include Homebrew. Setup then:

- copies the helper to `/Library/PrivilegedHelperTools/clamshellctl-helper`;
- sets ownership to `root:wheel` and mode `0755`;
- writes `/etc/sudoers.d/clamshellctl` with mode `0440`;
- permits the current user to run only the helper's exact `enable` and `disable` commands without a password;
- validates the sudoers file with `/usr/sbin/visudo -cf` before reporting success; and
- performs a read-only installation check.

The sudoers rule never grants password-free access to arbitrary `pmset` arguments, the public CLI, a shell, or a user-writable file.

`uninstall` removes only the helper and its sudoers file after validating their expected paths. When the companion created the optional `/usr/local/bin/clamshellctl` symlink, removal also deletes that symlink after verifying that it targets the companion bundle. Homebrew remains responsible for uninstalling a Homebrew-managed CLI. Removing the privileged components is safe to repeat.

## Timed enablement

`enable --for <duration>` records an absolute deadline and installs a user LaunchAgent dedicated to the pending disable operation. The LaunchAgent calls the installed CLI with `disable --quiet`, then removes its timer metadata after a successful or terminal attempt.

The timer is based on an absolute deadline so sleep does not restart its duration. If macOS cannot run the job at the exact deadline, the disable operation runs when the user LaunchAgent is next eligible. `status` ignores stale timer metadata after its deadline and reports an actionable warning if cleanup is required.

Timer files use a stable application-support location under the user's Library and do not require root access.

## Companion app and Control Centre

The companion supplies a `ControlWidgetToggle` rather than a traditional widget or Shortcut. Its value provider displays the battery clamshell state read directly from `pmset`. Its `SetValueIntent` requests the exact state selected by the user instead of blindly toggling, which makes retries and optimistic system UI updates safe. The intent can execute from the system's selected app or extension process, but it reaches privilege only through the installed root-owned helper's exact `enable` or `disable` command. No app or extension process invokes `pmset` with mutation arguments directly.

When enabled, the system renders the control in its active appearance; when disabled, it renders the inactive appearance. After an action completes, the app requests a control reload so the displayed value is reconciled with the `pmset` source of truth.

The unsigned distribution path has a mandatory feasibility gate before release. An ad-hoc-signed build must prove on a clean local account that macOS discovers the extension after Gatekeeper approval, the value provider can obtain current state, the intent can reach only the narrow helper operation, and an app update preserves the control and privileged setup. If any part of that boundary cannot be secured without Developer ID capabilities, the CLI ships independently while the companion remains unreleased rather than broadening privileges.

The project cannot add the control to Control Centre automatically. Setup provides concise instructions and verifies discovery, while placement remains the user's explicit macOS personalisation choice.

## DMG distribution

GitHub Releases publish an ad-hoc-signed DMG containing `Clamshell.app`. A free Apple Account is sufficient to develop and test the app, but it does not provide Developer ID signing or notarisation. The README therefore explains the initial Gatekeeper warning and the exact Privacy & Security `Open Anyway` flow without implying that the app has been reviewed by Apple.

The app bundle contains the control extension, shared implementation, bundled CLI, and helper payload. Dragging the app to `/Applications` is the only application installation step. First-run setup performs the privileged installation separately so the security-sensitive helper is immutable by the normal user.

Removing privileged setup deletes only the root-owned helper, sudoers rule, and optional CLI symlink. Removing `Clamshell.app` deletes the companion and Control Centre extension. The app and documentation guide users to remove privileged setup before deleting the bundle.

## Errors and recovery

User-facing errors are concise and actionable:

- missing helper or sudoers rule: provide the exact setup command;
- malformed duration: show the accepted duration forms;
- unsupported or unrecognised `pmset` output: report that the current macOS behaviour is unsupported rather than guessing;
- permission failure: identify the privileged setup as invalid and suggest rerunning setup;
- failed state verification: report the expected and observed states;
- timer installation failure: disable the newly enabled mode unless the user explicitly requested permanent enablement; and
- unavailable Control Centre action: direct the user to open the companion for helper and extension diagnostics.

Diagnostic command output is included only when it is safe and useful. No operation silently broadens privileges or changes AC-power settings.

## Repository layout

```text
clamshellctl/
├── .github/
│   ├── ISSUE_TEMPLATE/
│   ├── workflows/
│   ├── CODEOWNERS
│   ├── CONTRIBUTING.md
│   ├── SECURITY.md
│   └── SUPPORT.md
├── Sources/
│   ├── ClamshellCore/
│   │   ├── Errors/
│   │   ├── Power/
│   │   ├── Privilege/Installation/
│   │   ├── Process/
│   │   ├── State/
│   │   └── Timing/              # Added with timed enablement
│   ├── ClamshellCLI/
│   │   └── Commands/
│   └── ClamshellHelper/
├── App/
│   ├── ClamshellApp/
│   └── ClamshellControl/
├── Tests/
│   ├── ClamshellCoreTests/
│   │   ├── Power/
│   │   ├── Privilege/Installation/
│   │   ├── Process/
│   │   ├── State/
│   │   └── Support/
│   └── ClamshellCLITests/Commands/
├── docs/
│   ├── assets/
│   └── clamshellctl-design.md
├── scripts/
├── .release-please-manifest.json
├── CHANGELOG.md
├── LICENSE
├── Package.swift
├── README.md
├── release-please-config.json
├── version.txt
└── project.yml                 # Added with the native companion
```

The approved transparent artwork is stored as `docs/assets/clamshellctl.png` and used near the top of the README.

`project.yml` is the reviewable source of truth for the native targets. XcodeGen creates `Clamshell.xcodeproj` locally and in CI; the generated project is not committed.

## Testing and verification

Unit tests cover:

- recognised and malformed `pmset` output;
- enabled, disabled, and unexpected states;
- idempotent command decisions;
- duration parsing and absolute-deadline calculation;
- timer replacement and cancellation;
- helper argument rejection;
- generated sudoers contents and file paths; and
- error rendering and exit-status mapping.

Integration tests execute the CLI and helper against fake process runners and temporary files. CI never invokes a real privileged mutation or changes a runner's power settings.

GitHub Actions runs Swift build and test jobs on macOS. Release readiness also requires a manual acceptance pass on a Mac notebook covering battery enablement, AC behaviour remaining unchanged, disablement, toggle, timed disablement, and setup removal.

The companion has an additional clean-account acceptance pass covering Gatekeeper approval, first-run privileged setup, Control Centre discovery, correct active and inactive rendering, external CLI state changes, app updates, optional CLI exposure, and complete removal. The release workflow does not publish the DMG until these behaviours pass with the actual ad-hoc-signed release artefact.

## Releases

The project uses Conventional Commits and release-please, matching the established Kotventure workflow.

- `googleapis/release-please-action` v5 is pinned to an exact commit SHA.
- The manifest configuration uses `release-type: simple` for the single root package.
- Development begins at `0.1.0` and uses `v0.1.0`-style tags.
- Pre-1.0 features bump the minor version and fixes bump the patch version.
- Release PRs update `CHANGELOG.md`, `.release-please-manifest.json`, `version.txt`, and the Swift version source used by `clamshellctl --version`.
- Changelog sections follow Kotventure's style but remain limited to features, fixes, refactors, and documentation; tests and routine chores are hidden.
- Pull-request titles are validated as Conventional Commits so squash merges feed release-please correctly.

The release workflow uses `RELEASE_PLEASE_TOKEN`, with `GITHUB_TOKEN` available only as a documented fallback, so CI runs on release-please PRs. It uses a separate, narrowly scoped `TAP_GITHUB_TOKEN` to update the Homebrew tap.

Merging the release PR creates the version tag and GitHub Release. The action's `release_created` output gates subsequent publication work in the same workflow.

The GitHub Release also contains the companion DMG when its native acceptance gate is enabled for that release. Homebrew publication and the CLI release remain independent of DMG eligibility so a companion-specific failure cannot block CLI users.

## Homebrew distribution

The existing `LMLiam/homebrew-tap` repository receives `Formula/clamshellctl.rb`.

The formula builds the Swift package from the tagged source release instead of distributing an unsigned prebuilt binary. It installs the public CLI and helper payload, prints the explicit privileged setup command as a caveat, and tests the installation with `clamshellctl --version` without changing system power settings.

When release-please creates a release, the publication job calculates the new source checksum, generates the formula, validates it, and updates `homebrew-tap`. The workflow follows the proven cross-repository authentication pattern used by `remote-monitor` while omitting GoReleaser, multi-platform binaries, SBOM generation, and other machinery that does not serve this macOS-only Swift utility.

The documented installation flow is:

```text
brew install LMLiam/tap/clamshellctl
sudo "$(brew --prefix)/bin/clamshellctl" setup
```

No paid Apple Developer Programme membership is required for this source-build distribution model.

The DMG is the independent installation path for users who want the native Control Centre experience. It does not require Homebrew and includes the same version of the CLI and helper payload as the tagged source release.

## Public repository and community setup

The local repository lives at `/Users/liam/Developer/clamshellctl`. The public repository is `LMLiam/clamshellctl`, uses the `main` branch, and is licensed under MIT.

The initial public setup includes:

- a concise README with the logo, purpose, safety explanation, Homebrew and DMG installation, setup, Control Centre placement, Gatekeeper approval, troubleshooting, and uninstall instructions;
- contribution, security, and support documents;
- focused issue templates;
- CI, Conventional PR-title validation, release-please, and Homebrew publication workflows; and
- GitHub issues that describe the intended outcome and retain the approved implementation plan in their bodies.

Initial issues cover the core CLI, privileged setup, timed enablement, native companion feasibility, Control Centre integration, DMG packaging, documentation, Homebrew publication, and release automation. A later issue covers USB-C disconnect automation.

After the first public release succeeds, `LMLiam/LMLiam` is updated to feature `clamshellctl` on the GitHub profile.

## Success criteria

The initial release is complete when:

- a fresh Homebrew installation and one-time setup work on a supported Mac notebook;
- all public commands behave as documented and verify their results;
- AC-power settings are never changed;
- repeated operations and uninstall are safe;
- the timed-disable path survives ordinary sleep and cancels correctly;
- the optional companion installs without Homebrew and exposes a stateful toggle in Control Centre;
- the Control Centre appearance matches the verified `pmset` state after app, CLI, and timer changes;
- the ad-hoc-signed release passes the clean-account security and lifecycle acceptance gate;
- CI passes without privileged mutation;
- merging a release-please PR creates the GitHub Release and updates the Homebrew formula; and
- the public README and GitHub profile link users to the project.
