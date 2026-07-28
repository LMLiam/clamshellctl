# clamshellctl Design

## Summary

`clamshellctl` is a macOS command-line utility that allows a Mac notebook to remain awake in clamshell mode while it is running on battery power. It wraps the relevant `pmset` setting behind a small, testable Swift CLI and a narrowly restricted privileged helper.

The CLI is the primary product. An optional macOS Shortcut provides convenient access from Control Centre without adding a menu-bar item. Homebrew is the primary installation method.

## Goals

- Provide clear `status`, `enable`, `disable`, and `toggle` commands.
- Support temporary enablement with `enable --for <duration>`.
- Require an administrator password only during initial privileged setup or removal.
- Keep password-free operation limited to the two required `pmset` mutations.
- Make repeated commands safe and idempotent.
- Provide an optional Shortcut that users can add to Control Centre.
- Publish releases through release-please and distribute through `LMLiam/homebrew-tap`.
- Work on both Apple silicon and Intel Macs supported by the selected Swift toolchain.

## Non-goals for v1

- A menu-bar application.
- A native WidgetKit Control Widget with dynamic enabled-state colouring.
- Apple Developer Programme signing or notarisation.
- Automatically changing the setting when USB-C devices are disconnected.
- Linux or Windows support.
- JSON output or a persistent application database.

Automatic USB-C disconnect handling remains a separate future issue because the implementation must distinguish displays and power sources from unrelated USB-C devices.

## User experience

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

`--quiet` suppresses successful output for Shortcuts and scripts. Errors still go to standard error and use a non-zero exit status.

Durations accept a deliberately small syntax: whole numbers followed by `m`, `h`, or `d`, such as `30m`, `2h`, or `1d`. A new timed enable replaces an existing timer. Manual disablement cancels any active timer.

## Architecture

The Swift package contains three production targets and two executable products:

1. `ClamshellCore` owns state parsing, command decisions, duration handling, timer metadata, setup-file generation, and domain errors. It does not execute privileged system changes directly.
2. `ClamshellCLI` produces the `clamshellctl` executable. It parses arguments, reads current state, invokes the helper when needed, manages the timer, and renders user-facing output.
3. `ClamshellHelper` produces the `clamshellctl-helper` executable. It accepts only `enable` or `disable`, invokes `pmset`, and verifies the resulting state.

System commands are accessed through injected process-running interfaces so unit and integration tests can use deterministic fakes. `pmset` remains the sole source of truth for whether battery clamshell mode is enabled.

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

Homebrew installs the public CLI and an unprivileged helper payload. It does not run privileged installation steps.

The documented setup command runs the installed CLI with `sudo`, using its explicit Homebrew path where the administrator's secure path does not include Homebrew. Setup then:

- copies the helper to `/usr/local/libexec/clamshellctl-helper`;
- sets ownership to `root:wheel` and mode `0755`;
- writes `/etc/sudoers.d/clamshellctl` with mode `0440`;
- permits the current user to run only the helper's exact `enable` and `disable` commands without a password;
- validates the sudoers file with `/usr/sbin/visudo -cf` before reporting success; and
- performs a read-only installation check.

The sudoers rule never grants password-free access to arbitrary `pmset` arguments, the public CLI, a shell, or a user-writable file.

`uninstall` removes only the helper and its sudoers file after validating their expected paths. Homebrew remains responsible for uninstalling the public CLI. Removing the privileged components is safe to repeat.

## Timed enablement

`enable --for <duration>` records an absolute deadline and installs a user LaunchAgent dedicated to the pending disable operation. The LaunchAgent calls the installed CLI with `disable --quiet`, then removes its timer metadata after a successful or terminal attempt.

The timer is based on an absolute deadline so sleep does not restart its duration. If macOS cannot run the job at the exact deadline, the disable operation runs when the user LaunchAgent is next eligible. `status` ignores stale timer metadata after its deadline and reports an actionable warning if cleanup is required.

Timer files use a stable application-support location under the user's Library and do not require root access.

## Shortcut and Control Centre

The repository and release assets include an importable Shortcut. The Shortcut locates Homebrew in `/opt/homebrew` or `/usr/local`, then runs `clamshellctl toggle --quiet`.

macOS requires the user to approve importing the Shortcut and add it to Control Centre manually. The project does not claim that setup can bypass those privacy controls.

The Shortcut tile cannot reflect the live enabled state. Dynamic colouring would require a native WidgetKit Control Widget, application packaging, signing, and the Apple distribution path that is explicitly outside v1.

## Errors and recovery

User-facing errors are concise and actionable:

- missing helper or sudoers rule: provide the exact setup command;
- malformed duration: show the accepted duration forms;
- unsupported or unrecognised `pmset` output: report that the current macOS behaviour is unsupported rather than guessing;
- permission failure: identify the privileged setup as invalid and suggest rerunning setup;
- failed state verification: report the expected and observed states;
- timer installation failure: disable the newly enabled mode unless the user explicitly requested permanent enablement; and
- missing Homebrew CLI from the Shortcut: direct the user to install or repair `clamshellctl`.

Diagnostic command output is included only when it is safe and useful. No operation silently broadens privileges or changes AC-power settings.

## Repository layout

```text
clamshellctl/
├── .github/
│   ├── ISSUE_TEMPLATE/
│   └── workflows/
├── Sources/
│   ├── ClamshellCore/
│   ├── ClamshellCLI/
│   └── ClamshellHelper/
├── Tests/
│   └── ClamshellCoreTests/
├── Shortcuts/
├── docs/
│   ├── assets/
│   └── clamshellctl-design.md
├── .release-please-manifest.json
├── CHANGELOG.md
├── CONTRIBUTING.md
├── LICENSE
├── Package.swift
├── README.md
├── SECURITY.md
├── SUPPORT.md
├── release-please-config.json
└── version.txt
```

The approved transparent artwork is stored as `docs/assets/clamshellctl.png` and used near the top of the README.

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

GitHub Actions runs Swift build and test jobs on macOS. Release readiness also requires a manual acceptance pass on a Mac notebook covering battery enablement, AC behaviour remaining unchanged, disablement, toggle, timed disablement, setup removal, and Shortcut invocation.

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

## Public repository and community setup

The local repository lives at `/Users/liam/Developer/clamshellctl`. The public repository is `LMLiam/clamshellctl`, uses the `main` branch, and is licensed under MIT.

The initial public setup includes:

- a concise README with the logo, purpose, safety explanation, installation, setup, usage, Shortcut import, troubleshooting, and uninstall instructions;
- contribution, security, and support documents;
- focused issue templates;
- CI, Conventional PR-title validation, release-please, and Homebrew publication workflows; and
- GitHub issues that describe the intended outcome and retain the approved implementation plan in their bodies.

Initial issues cover the core CLI, privileged setup, timed enablement, Shortcut packaging, documentation, Homebrew publication, and release automation. Later issues cover USB-C disconnect automation and reconsidering native Control Centre state only if the signing constraint changes.

After the repository is public and its README is ready, `LMLiam/LMLiam` is updated to feature `clamshellctl` on the GitHub profile.

## Success criteria

The initial release is complete when:

- a fresh Homebrew installation and one-time setup work on a supported Mac notebook;
- all public commands behave as documented and verify their results;
- AC-power settings are never changed;
- repeated operations and uninstall are safe;
- the timed-disable path survives ordinary sleep and cancels correctly;
- the imported Shortcut can toggle the mode from Control Centre;
- CI passes without privileged mutation;
- merging a release-please PR creates the GitHub Release and updates the Homebrew formula; and
- the public README and GitHub profile link users to the project.
