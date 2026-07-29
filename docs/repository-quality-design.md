# Repository Quality Design

## Summary

This document defines the quality standard for `clamshellctl`. It covers Swift
style enforcement, source organisation, continuous integration, repository
governance, security scanning, and the GitGuardian test-fixture finding.

The goal is an idiomatic and maintainable Swift project whose local checks and
GitHub checks produce the same result. The work must preserve the existing CLI
behaviour and privileged-operation boundaries.

## Style enforcement

The project follows the [Google Swift Style Guide][google-swift-style]. Two
tools enforce separate parts of that standard:

- `swift-format` owns source formatting. Its checked-in `.swift-format`
  configuration uses two-space indentation, a 100-column line limit,
  deterministic imports, and the applicable Google conventions.
- [SwiftLint][swiftlint] owns maintainability and correctness rules that
  formatting cannot express. Its checked-in `.swiftlint.yml` covers naming,
  API hygiene, unsafe constructs, complexity, and selected opt-in rules.

SwiftLint is a standalone development tool. It is not a production package
dependency. Local verification requires version 0.65.0. The GitHub
`macos-26` runner also includes this version. This configuration keeps lint
tools out of production builds and CodeQL builds. Local checks and CI use the
same rules.

SwiftLint configuration must be deliberate. The project does not enable every
opt-in rule, duplicate formatting rules owned by `swift-format`, or accept a
baseline of existing violations. A suppression must be limited to the smallest
declaration or line and include a reason when the code does not make the reason
obvious.

`.editorconfig` defines editor-neutral properties for Swift and repository
files: UTF-8, LF endings, a final newline, trailing-whitespace handling, and
two-space indentation where appropriate. It complements the Swift tools; it is
not the source of truth for Swift syntax formatting.

## Documentation style

All documentation uses ASD-STE100 Simplified Technical English and British
English spelling. Sentences are short and use active voice. Each instruction
contains one action. Each item or action has one term.

Technical accuracy has priority over the controlled vocabulary. Product names,
commands, code identifiers, API names, quoted interface text, and standard
names can use their required terms.

## Source organisation

Directories describe responsibilities rather than current consumers. The core
module uses these domains:

```text
Sources/ClamshellCore/
├── Errors/
├── Power/
├── Privilege/
│   └── Installation/
├── Process/
├── State/
└── Timing/
```

- `State` owns the clamshell state and state-transition decisions.
- `Power` owns `pmset` parsing and the read or mutation boundary.
- `Process` owns process invocation values, protocols, and Foundation adapters.
- `Privilege` owns the helper client and the exact sudoers policy.
- `Privilege/Installation` owns privileged installation and removal workflows,
  their filesystem boundary, and operation results.
- `Timing` owns duration parsing, timer metadata, and timer lifecycle rules.
- `Errors` owns domain errors and their stable presentation or exit semantics.

CLI subcommands remain in `Sources/ClamshellCLI/Commands`. Command composition,
console output, and entry-point concerns use focused files outside that folder.
The helper remains a thin executable target. Future app and control-extension
folders continue to follow the architecture in `clamshellctl-design.md`.

Tests mirror production responsibilities:

```text
Tests/ClamshellCoreTests/
├── Power/
├── Privilege/
│   └── Installation/
├── Process/
├── State/
├── Support/
└── Timing/
```

Reusable test infrastructure belongs in `Support`. A fake used by one suite
remains private in that suite's file.

## File and declaration boundaries

A production file has one primary responsibility, usually represented by one
primary top-level type. This is a design rule rather than a declaration-count
rule. Closely related declarations may share a file when separating them would
make the code harder to understand. Examples include:

- A protocol beside its sole production implementation.
- A small result value beside the operation that returns it.
- A private helper used only by the file's primary type.
- A test suite and its suite-specific private fakes.

Independent public types, reusable protocols, and unrelated operation results
use separate files. Existing mixed-responsibility files are split where they
cross these boundaries. In particular, privileged installation workflow,
filesystem access, Foundation filesystem adaptation, and installation results
must not remain bundled as unrelated declarations in one large file.

The project does not add a brittle script that counts top-level declarations.
SwiftLint complexity limits and code review enforce the intent while preserving
the useful exceptions in the Google guide.

## Idiomatic Swift boundaries

`ClamshellCore` stays independent of argument parsing, SwiftUI, WidgetKit, and
App Intents. Domain decisions use values and narrow protocols. Foundation types
adapt operating-system behaviour at the edge.

System operations remain injectable. Tests must not invoke real `pmset`,
`sudo`, filesystem ownership changes, or `launchd`. Generic dumping grounds
such as `Utils`, `Common`, or `Models` are prohibited.

Access control is as narrow as target boundaries permit. Declarations exposed
to the future app package product are public. Other declarations remain
internal or private. Documentation is added when it records contracts,
constraints, or failure behaviour that the declaration does not make clear;
implementation comments explain non-obvious decisions instead of restating
code.

The refactor does not change command output, exit codes, accepted arguments,
privileged paths, or the sudoers allow-list unless a separate behaviour change
is explicitly designed and tested.

## Error handling

Errors remain typed and actionable. Domain errors preserve stable CLI exit-code
behaviour. Platform adapters include enough underlying context to diagnose a
failure but do not expose sensitive command output unnecessarily.

The codebase does not introduce forced casts, forced tries, avoidable forced
unwraps, silent catches, or `fatalError` for recoverable conditions. A process,
filesystem, parsing, or verification failure propagates through an explicit
error path and receives behavioural test coverage.

## Testing and local verification

Tests verify externally observable behaviour rather than private implementation
shape. Coverage includes:

- Valid and malformed battery sections in `pmset` output.
- Idempotent enable and disable transitions.
- Exact privileged command allow-listing.
- Installation ownership, permissions, rollback, and repeatability.
- Process output capture and failure propagation.
- CLI exit codes and human-readable output.
- Regression protection before existing code is moved or rewritten.

The repository exposes one documented local verification entry point. It runs,
in order:

1. `swift-format` in strict lint mode.
2. SwiftLint in strict lint mode.
3. The complete Swift test suite.
4. Debug and release package builds.
5. XcodeGen and the companion-app build once those targets exist.

Each command stops on failure and preserves the failing tool's output. CI uses
the same commands rather than maintaining an independent implementation.

## GitHub Actions

All third-party actions are pinned to immutable commit SHAs. Workflows receive
the minimum required permissions.

### Continuous integration

`ci.yml` runs on pull requests and pushes to `main` using a macOS runner. It
checks formatting, runs SwiftLint, executes tests, and builds debug and release
configurations. It also generates and builds the Xcode project after the native
targets are introduced.

### CodeQL

`codeql.yml` uses [GitHub CodeQL][codeql-compiled] to analyse Swift on pull
requests, pushes to `main`, a weekly schedule, and manual dispatch. It runs on
macOS and uses an explicit manual Swift build so the analysed targets are
deterministic. The workflow enables the `security-extended` query suite and
publishes results through GitHub code scanning.

### Pull-request titles

`pr.yml` enforces `verb(area): description`. Accepted verbs follow the
repository's release-please conventions. The same structure is used for local
commits.

### Automated review

`.coderabbit.yaml` is the version-controlled source of truth for automated
review. [CodeRabbit][coderabbit-config] uses British English and an assertive,
high-signal profile. It prioritises correctness, security, maintainability, and
idiomatic Swift. Review comments must identify a concrete consequence and must
not request cosmetic churn, redundant comments, or documentation for
self-explanatory implementation details.

CodeRabbit reviews a pull request when it becomes ready for review. It does not
review drafts or rerun automatically after each push. Maintainers batch fixes
and request a manual follow-up review when the result justifies another review.
Actionable findings use GitHub's request changes workflow.

The walkthrough remains concise and collapsed. It omits poems, fortunes,
sequence diagrams, effort estimates, suggested labels or reviewers, and prompts
for automated code generation. Swift, tests, privileged code, workflows, shell
scripts, and documentation receive focused path-specific instructions.

The docstring coverage and generation features are disabled. The deterministic
`pr.yml` check owns title syntax, so CodeRabbit does not duplicate it with a
subjective title check. Description and linked-issue checks remain advisory.
SwiftLint reads `.swiftlint.yml`, and ShellCheck remains enabled.

### Releases and dependency updates

`release.yml` uses release-please to create release pull requests and GitHub
releases. Artifact upload remains output-gated until the CLI and DMG packaging
work exists. Dependabot checks Swift Package Manager and GitHub Actions weekly
and groups compatible routine updates.

## Repository configuration

The public repository has a clear description and relevant topics. Issues
remain enabled. Unused wiki and project features are disabled. Merge
configuration allows squash merges only and deletes merged branches
automatically.

Repository metadata includes:

- `CODEOWNERS`, assigning the repository to `@LMLiam`.
- A pull-request template.
- Structured bug, feature, and security issue forms.
- Contributing, security, and support policies in GitHub's recognised
  `.github` locations.
- Consistent type, area, priority, and status labels.
- An MVP milestone for the existing implementation issues.

Private vulnerability reporting, Dependabot alerts, Dependabot security
updates, secret scanning, and push protection are enabled where GitHub makes
them available to the public repository.

## Main branch ruleset

The default-branch ruleset requires:

- A pull request before merging.
- One approving maintainer and code-owner review.
- Dismissal of stale approvals after relevant changes.
- Resolution of every review conversation.
- Passing CI, CodeQL, pull-request-title, and GitGuardian checks.
- Linear history.

Force pushes and branch deletion are blocked. Repository administrators retain
a bypass so Liam can deliberately admin-merge his own pull requests.

The ruleset is enabled only after each required workflow has produced its
stable check name. This prevents a configuration that requires a check GitHub
has never observed and therefore cannot satisfy.

## GitGuardian finding

The current GitGuardian detection is a sudoers-policy test fixture containing a
sample username and an allowed helper command. It is neither a password nor a
credential.

The individual incident is resolved with GitGuardian's `Skip: false positive`
action. The implementation must not ignore the test directory, disable the
detector, add a broad match exclusion, or rewrite Git history. Secret scanning
and future detections remain fully active.

## Completion criteria

The quality pass is complete when:

1. The source and tests follow the approved responsibility-based layout.
2. `swift-format` and SwiftLint pass in strict mode with no unexplained
   suppressions.
3. All tests and debug and release builds pass.
4. CI and CodeQL complete successfully on the pull request.
5. The GitGuardian false positive is resolved and its check passes.
6. Repository metadata, security features, labels, merge settings, and the
   default-branch ruleset match this design.
7. Existing architecture and implementation documentation matches the final
   layout and workflows.
8. A final review finds no unresolved correctness, security, or maintainability
   issues.

[codeql-compiled]: https://docs.github.com/en/code-security/concepts/code-scanning/codeql/codeql-for-compiled-languages
[coderabbit-config]: https://docs.coderabbit.ai/reference/configuration
[google-swift-style]: https://google.github.io/swift/
[swiftlint]: https://github.com/realm/SwiftLint
