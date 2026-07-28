# Repository Quality Implementation Plan

**Goal:** Make `clamshellctl` an idiomatic, consistently enforced Swift project
with a complete public GitHub repository, CodeQL analysis, release automation,
and protected-main governance.

**Architecture:** Preserve the current SwiftPM target boundaries and observable
CLI behaviour. Organise each target by responsibility, keep operating-system
interactions behind protocols, and give formatting, linting, testing, security,
and repository policy separate enforceable owners.

**Tech Stack:** Swift 6.3, Swift Package Manager, Swift Testing,
`swift-format`, SwiftLint 0.63.2, GitHub Actions, CodeQL, GitGuardian,
release-please v5, Dependabot, `actionlint`, and GitHub rulesets.

---

## File map

### Production source

```text
Sources/ClamshellCore/
├── BuildVersion.swift
├── Errors/ClamshellError.swift
├── Power/
│   ├── PowerMutation.swift
│   ├── PowerSettingsClient.swift
│   └── PowerSettingsParser.swift
├── Privilege/
│   ├── PrivilegedHelperClient.swift
│   ├── PrivilegedPaths.swift
│   ├── SudoersPolicy.swift
│   └── Installation/
│       ├── FoundationInstallationFileSystem.swift
│       ├── InstallationFileSystem.swift
│       ├── InstallationResult.swift
│       ├── PrivilegedInstallation.swift
│       └── UninstallationResult.swift
├── Process/
│   ├── FoundationProcessRunner.swift
│   ├── ProcessOutputStream.swift
│   ├── ProcessResult.swift
│   └── ProcessRunning.swift
└── State/
    ├── ClamshellService.swift
    ├── ClamshellState.swift
    ├── PowerStateReading.swift
    ├── PowerStateWriting.swift
    └── TransitionResult.swift

Sources/ClamshellCLI/
├── ClamshellCommand.swift
├── CommandComposition.swift
├── Console.swift
├── OutputOptions.swift
└── Commands/*.swift
```

`BuildVersion.swift` stays at the module root because it is package metadata,
not a domain. No one-file `Versioning` directory is introduced. Issue #4 adds
the `Timing` production and test directories when timed enablement exists; this
plan does not commit empty directories.

### Tests

```text
Tests/ClamshellCoreTests/
├── BuildVersionTests.swift
├── Power/*.swift
├── Privilege/*.swift
├── Privilege/Installation/*.swift
├── Process/FoundationProcessRunnerTests.swift
├── State/ClamshellServiceTests.swift
└── Support/InstallationTestSupport.swift

Tests/ClamshellCLITests/
└── Commands/
    ├── SetupCommandTests.swift
    └── StatusCommandTests.swift
```

### Quality and repository files

```text
.editorconfig
.gitattributes
.swift-format
.swiftlint.yml
.github/CODEOWNERS
.github/CODE_OF_CONDUCT.md
.github/CONTRIBUTING.md
.github/SECURITY.md
.github/SUPPORT.md
.github/dependabot.yml
.github/pull_request_template.md
.github/ISSUE_TEMPLATE/config.yml
.github/workflows/ci.yml
.github/workflows/codeql.yml
.github/workflows/pr.yml
.github/workflows/release.yml
.release-please-manifest.json
CHANGELOG.md
release-please-config.json
scripts/check.sh
scripts/check-conventional-subject.sh
```

The untracked `.vscode/` directory is user-owned and must remain untouched.

## Task 1: Record the behavioural baseline

**Files:** None.

- [ ] **Step 1: Confirm the protected worktree scope**

Run:

```bash
git status --short --branch
```

Expected: branch `feat/mvp`; the only untracked path is `.vscode/`.

- [ ] **Step 2: Run the current formatter check**

Run:

```bash
swift format lint --recursive --strict Sources Tests Package.swift
```

Expected: exit 0 before the formatting configuration changes.

- [ ] **Step 3: Run the current tests and builds**

Run:

```bash
swift test
swift build
swift build -c release
```

Expected: 33 tests in 12 suites pass; both builds exit 0.

## Task 2: Organise source and tests by responsibility

**Files:**

- Move: existing Swift files under `Sources/ClamshellCore/`
- Move: `Sources/ClamshellCLI/ClamshellCommand.swift`
- Move: `Sources/ClamshellCLI/Console.swift`
- Move: existing Swift test files under `Tests/`

- [ ] **Step 1: Create the responsibility directories**

Run:

```bash
mkdir -p Sources/ClamshellCore/{Errors,Power,Privilege/Installation,Process,State}
mkdir -p Tests/ClamshellCoreTests/{Power,Privilege/Installation,Process,State,Support}
mkdir -p Tests/ClamshellCLITests/Commands
```

- [ ] **Step 2: Move each intact production file**

Run:

```bash
git mv Sources/ClamshellCore/ClamshellError.swift Sources/ClamshellCore/Errors/
git mv Sources/ClamshellCore/ClamshellService.swift Sources/ClamshellCore/State/
git mv Sources/ClamshellCore/ClamshellState.swift Sources/ClamshellCore/State/
git mv Sources/ClamshellCore/PowerSettingsClient.swift Sources/ClamshellCore/Power/
git mv Sources/ClamshellCore/PowerSettingsParser.swift Sources/ClamshellCore/Power/
git mv Sources/ClamshellCore/PrivilegedHelperClient.swift \
  Sources/ClamshellCore/Privilege/
git mv Sources/ClamshellCore/PrivilegedInstallation.swift \
  Sources/ClamshellCore/Privilege/Installation/
git mv Sources/ClamshellCore/ProcessRunner.swift Sources/ClamshellCore/Process/
git mv Sources/ClamshellCore/SudoersPolicy.swift Sources/ClamshellCore/Privilege/
```

SwiftPM discovers target sources recursively, so `Package.swift` does not need
path declarations.

- [ ] **Step 3: Move each intact test file**

Run:

```bash
git mv Tests/ClamshellCoreTests/ClamshellServiceTests.swift Tests/ClamshellCoreTests/State/
git mv Tests/ClamshellCoreTests/PowerMutationTests.swift Tests/ClamshellCoreTests/Power/
git mv Tests/ClamshellCoreTests/PowerSettingsClientTests.swift Tests/ClamshellCoreTests/Power/
git mv Tests/ClamshellCoreTests/PowerSettingsParserTests.swift Tests/ClamshellCoreTests/Power/
git mv Tests/ClamshellCoreTests/PrivilegedHelperClientTests.swift \
  Tests/ClamshellCoreTests/Privilege/
git mv Tests/ClamshellCoreTests/PrivilegedInstallationTests.swift \
  Tests/ClamshellCoreTests/Privilege/Installation/
git mv Tests/ClamshellCoreTests/SudoersPolicyTests.swift Tests/ClamshellCoreTests/Privilege/
git mv Tests/ClamshellCLITests/SetupCommandTests.swift Tests/ClamshellCLITests/Commands/
```

- [ ] **Step 4: Verify the moves did not change behaviour**

Run:

```bash
swift test
swift build -c release
```

Expected: all 33 tests pass and the release build exits 0.

- [ ] **Step 5: Commit the mechanical layout change**

Run:

```bash
git add Sources Tests
git commit -m "refactor(layout): organise code by responsibility"
```

## Task 3: Split mixed-responsibility production files

**Files:**

- Modify: `Sources/ClamshellCore/State/ClamshellService.swift`
- Create: `Sources/ClamshellCore/State/PowerStateReading.swift`
- Create: `Sources/ClamshellCore/State/PowerStateWriting.swift`
- Create: `Sources/ClamshellCore/State/TransitionResult.swift`
- Modify: `Sources/ClamshellCore/Power/PowerSettingsClient.swift`
- Create: `Sources/ClamshellCore/Power/PowerMutation.swift`
- Replace: `Sources/ClamshellCore/Process/ProcessRunner.swift`
- Create: four focused files under `Sources/ClamshellCore/Process/`
- Modify: `Sources/ClamshellCore/Privilege/SudoersPolicy.swift`
- Create: `Sources/ClamshellCore/Privilege/PrivilegedPaths.swift`
- Replace: `Sources/ClamshellCore/Privilege/Installation/PrivilegedInstallation.swift`
- Create: four supporting installation files
- Modify: `Sources/ClamshellCLI/ClamshellCommand.swift`
- Create: `Sources/ClamshellCLI/CommandComposition.swift`
- Modify: `Sources/ClamshellCLI/Console.swift`
- Create: `Sources/ClamshellCLI/OutputOptions.swift`

- [ ] **Step 1: Separate state contracts and results**

Move the two protocols and result value out of `ClamshellService.swift` without
changing their names or signatures. The resulting files contain:

```swift
// PowerStateReading.swift
public protocol PowerStateReading: Sendable {
  func currentState() throws -> ClamshellState
}

// PowerStateWriting.swift
public protocol PowerStateWriting: Sendable {
  func setState(_ state: ClamshellState) throws
}

// TransitionResult.swift
public struct TransitionResult: Sendable, Equatable {
  public let previous: ClamshellState
  public let current: ClamshellState
  public let didChange: Bool

  public init(previous: ClamshellState, current: ClamshellState, didChange: Bool) {
    self.previous = previous
    self.current = current
    self.didChange = didChange
  }
}
```

`ClamshellService.swift` then contains only `ClamshellService`.

- [ ] **Step 2: Separate power mutation arguments**

Move `PowerMutation` unchanged from `PowerSettingsClient.swift` into
`PowerMutation.swift`. Keep the client focused on reading and writing `pmset`.

- [ ] **Step 3: Separate process values, protocol, and adapter**

Delete `ProcessRunner.swift` after distributing its declarations exactly as
follows:

```text
ProcessOutputStream.swift     ProcessOutputStream
ProcessResult.swift           ProcessResult
ProcessRunning.swift          ProcessRunning
FoundationProcessRunner.swift FoundationProcessRunner and private ProcessOutputCollector
```

The collector remains private beside its sole consumer. Do not change process
launching, concurrent pipe collection, UTF-8 validation, or returned values.

- [ ] **Step 4: Separate privileged paths from policy generation**

Move `PrivilegedPaths` unchanged into `PrivilegedPaths.swift`.
`SudoersPolicy.swift` then contains only username validation and exact policy
generation.

- [ ] **Step 5: Separate installation workflow and filesystem adaptation**

Distribute the declarations from `PrivilegedInstallation.swift` as follows:

```text
InstallationFileSystem.swift           InstallationFileSystem and InstalledFileAttributes
FoundationInstallationFileSystem.swift FoundationInstallationFileSystem
InstallationResult.swift               InstallationResult
UninstallationResult.swift             UninstallationResult
PrivilegedInstallation.swift           PrivilegedInstallation
```

Keep `InstalledFileAttributes` beside the protocol whose method returns it.
Retain every existing path, permission (`0755` and `0440`), ownership check,
temporary-file cleanup, `visudo` validation, and idempotency branch. Stage both
replacement files before validation, validate the staged policy, then replace
the policy before the helper. This avoids changing either live path when
staging or validation fails; the two separate filesystem renames are not a
single transaction.

- [ ] **Step 6: Separate CLI composition and output options**

Move `CommandComposition` unchanged into `CommandComposition.swift` and
`OutputOptions` unchanged into `OutputOptions.swift`. Leave
`ClamshellCommand.swift` and `Console.swift` with one primary responsibility
each.

- [ ] **Step 7: Move the Foundation process tests to their domain**

Move `FoundationProcessRunnerTests` from
`Tests/ClamshellCoreTests/Power/PowerSettingsClientTests.swift` into
`Tests/ClamshellCoreTests/Process/FoundationProcessRunnerTests.swift`. Keep its
temporary executable fixture and assertions unchanged.

- [ ] **Step 8: Extract the large installation fixture**

Move these test-only declarations from
`Tests/ClamshellCoreTests/Privilege/Installation/PrivilegedInstallationTests.swift`
to `Tests/ClamshellCoreTests/Support/InstallationTestSupport.swift`:

```text
InstallationOperation
InstallationOperationLog
InstallationRecordingRunner
RecordingInstallationFileSystem
```

Remove `private` only where cross-file test access requires internal access.
Keep suite-specific constants and test methods in the suite file.

- [ ] **Step 9: Verify the structural refactor**

Run:

```bash
swift test
swift build
swift build -c release
```

Expected: all 33 tests pass; both builds exit 0; command output and exit codes
are unchanged.

- [ ] **Step 10: Commit the focused declarations**

Run:

```bash
git add Sources Tests
git commit -m "refactor(core): separate domain responsibilities"
```

## Task 4: Enforce Google Swift formatting

**Files:**

- Create: `.editorconfig`
- Create: `.gitattributes`
- Modify: `.swift-format`
- Modify: `.gitignore`
- Modify: every checked-in Swift file through deterministic formatting

- [ ] **Step 1: Replace `.swift-format` with the explicit project policy**

Use:

```json
{
  "indentation": {
    "spaces": 2
  },
  "lineLength": 100,
  "maximumBlankLines": 1,
  "multiElementCollectionTrailingCommas": true,
  "rules": {
    "NeverForceUnwrap": true,
    "NeverUseForceTry": true,
    "NeverUseImplicitlyUnwrappedOptionals": true,
    "OrderedImports": true
  },
  "version": 1
}
```

- [ ] **Step 2: Add editor-neutral settings**

Create `.editorconfig`:

```ini
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true

[*.swift]
indent_style = space
indent_size = 2
max_line_length = 100

[{*.json,*.yml,*.yaml}]
indent_style = space
indent_size = 2

[*.md]
trim_trailing_whitespace = false
```

Create `.gitattributes`:

```gitattributes
* text=auto eol=lf
*.icns binary
*.png binary
*.dmg binary
```

Add these generated paths to `.gitignore` while preserving existing entries:

```gitignore
Clamshell.xcodeproj/
DerivedData/
```

- [ ] **Step 3: Confirm the formatter configuration changes the result**

Run:

```bash
swift format lint --recursive --strict Sources Tests Package.swift
```

Expected: non-zero with formatting diagnostics caused by the change from four
spaces to two.

- [ ] **Step 4: Apply formatting only**

Run:

```bash
swift format --recursive --in-place Sources Tests Package.swift
```

Expected: every Swift file uses two-space indentation and Google-compatible
layout. A second strict lint invocation exits 0.

- [ ] **Step 5: Commit the deterministic formatting**

Run:

```bash
git add .editorconfig .gitattributes .gitignore .swift-format Package.swift Sources Tests
git commit -m "style(swift): adopt Google formatting"
```

## Task 5: Add strict SwiftLint and useful API documentation

**Files:**

- Modify: `Package.swift`
- Modify: `Package.resolved`
- Modify: `.swift-format`
- Create: `.swiftlint.yml`
- Modify: public declarations under `Sources/`

- [ ] **Step 1: Pin the SwiftLint command plugin**

Add this exact dependency after `swift-argument-parser` in `Package.swift`:

```swift
.package(
  url: "https://github.com/SimplyDanny/SwiftLintPlugins",
  exact: "0.63.2"
),
```

Do not attach a build-tool plugin to any target. Resolve the exact dependency:

```bash
swift package resolve
```

The CLI test target imports ArgumentParser for command parsing, so it declares
the `ArgumentParser` product directly as well as depending on `ClamshellCLI`.

- [ ] **Step 2: Add a curated non-formatting SwiftLint policy**

First extend the `rules` object in `.swift-format` with the documentation rules
that become enforceable in this task:

```json
"BeginDocumentationCommentWithOneLineSummary": true,
"ValidateDocumentationComments": true
```

Create `.swiftlint.yml`:

```yaml
strict: true
check_for_updates: false
allow_zero_lintable_files: false

excluded:
  - .build
  - .swiftpm
  - Clamshell.xcodeproj
  - DerivedData

disabled_rules:
  - closing_brace
  - colon
  - comma
  - leading_whitespace
  - line_length
  - opening_brace
  - function_name_whitespace
  - return_arrow_whitespace
  - statement_position
  - force_try
  - trailing_comma
  - trailing_newline
  - trailing_semicolon
  - trailing_whitespace
  - vertical_whitespace

opt_in_rules:
  - array_init
  - closure_body_length
  - contains_over_filter_count
  - contains_over_filter_is_empty
  - discouraged_optional_boolean
  - empty_collection_literal
  - empty_count
  - empty_string
  - explicit_init
  - fatal_error_message
  - first_where
  - last_where
  - legacy_multiple
  - modifier_order
  - overridden_super_call
  - pattern_matching_keywords
  - reduce_into
  - redundant_nil_coalescing
  - sorted_first_last
  - toggle_bool
  - unavailable_function

closure_body_length:
  warning: 40
  error: 60
cyclomatic_complexity:
  warning: 10
  error: 15
file_length:
  warning: 400
  error: 500
  ignore_comment_only_lines: true
function_body_length:
  warning: 40
  error: 60
function_parameter_count:
  warning: 6
  error: 8
type_body_length:
  warning: 250
  error: 350

reporter: xcode
```

- [ ] **Step 3: Run SwiftLint to expose concrete violations**

Run:

```bash
swift package plugin --allow-writing-to-package-directory swiftlint --strict
```

Expected: non-zero until every reported correctness, naming, and complexity
violation is addressed. Do not create a baseline or disable a rule for the
whole repository.

- [ ] **Step 4: Document non-obvious public contracts**

Add concise `///` documentation only where it records behaviour that a
self-describing declaration does not communicate. Cover these contracts:

```text
PowerMutation          Accept only one exact helper action.
PowerSettingsParser    Define missing and malformed pmset behaviour.
PrivilegedHelperClient Restrict non-interactive helper invocation.
SudoersPolicy          Reject unsafe usernames and allow only exact commands.
PrivilegedInstallation Preserve staging, validation, verification, and idempotency.
ClamshellService       Avoid redundant writes and verify state transitions.
```

Do not document obvious properties, trivial initialisers, or declarations whose
names and types already state their complete contract. Do not add comments to
private implementation details unless the decision is non-obvious.

- [ ] **Step 5: Resolve every strict lint finding idiomatically**

Prefer changing code over suppressing a finding. When a rule is inapplicable,
use a line- or declaration-scoped disable with a reason immediately above it.
Run after each group of fixes:

```bash
swift format --recursive --in-place Sources Tests Package.swift
swift format lint --recursive --strict Sources Tests Package.swift
swift package plugin --allow-writing-to-package-directory swiftlint --strict
swift test
```

Expected: both linters exit 0 and all 33 tests pass.

- [ ] **Step 6: Commit linting and API documentation**

Run:

```bash
git add .swift-format .swiftlint.yml Package.swift Package.resolved Sources Tests
git commit -m "build(lint): enforce Swift conventions"
```

## Task 6: Add one local verification entry point

**Files:**

- Create: `scripts/check.sh`
- Create: `scripts/check-conventional-subject.sh`
- Modify: `.github/CONTRIBUTING.md` later in Task 9

- [ ] **Step 1: Add conventional-subject validation**

Create `scripts/check-conventional-subject.sh`:

```bash
#!/bin/bash
set -euo pipefail

readonly subject="${1:-}"
readonly verbs='feat|fix|docs|test|build|ci|refactor|perf|style|chore|revert'
readonly pattern="^(${verbs})\([a-z0-9][a-z0-9-]*\): .+"

if [[ ! "$subject" =~ $pattern ]]; then
  echo "Expected verb(area): description, received: $subject" >&2
  exit 1
fi
```

Dependency updates use `build(deps): ...`; `deps` is not a separate accepted
verb, so dependency commits stay inside the repository's standard vocabulary.

Make it executable and verify both branches:

```bash
chmod +x scripts/check-conventional-subject.sh
scripts/check-conventional-subject.sh "feat(cli): add status output"
! scripts/check-conventional-subject.sh "feat: add status output"
```

Expected: the scoped subject passes and the unscoped subject fails.

- [ ] **Step 2: Add the complete local check**

Create executable `scripts/check.sh`:

```bash
#!/bin/bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly repository_root
cd "$repository_root"

swift_paths=(Package.swift Sources Tests)
if [[ -d App ]]; then
  swift_paths+=(App)
fi

swift format lint --recursive --strict "${swift_paths[@]}"
swift package plugin --allow-writing-to-package-directory swiftlint --strict
swift test
swift build
swift build -c release

if [[ -d .github/workflows ]]; then
  command -v actionlint >/dev/null || {
    echo "actionlint is required: brew install actionlint" >&2
    exit 1
  }
  actionlint
fi

if [[ -f project.yml ]]; then
  command -v xcodegen >/dev/null || {
    echo "XcodeGen is required: brew install xcodegen" >&2
    exit 1
  }
  xcodegen generate
  xcodebuild \
    -project Clamshell.xcodeproj \
    -scheme ClamshellApp \
    -configuration Debug \
    CODE_SIGNING_ALLOWED=NO \
    build
fi
```

Run:

```bash
chmod +x scripts/check.sh
brew list actionlint >/dev/null 2>&1 || brew install actionlint
scripts/check.sh
```

Expected: both linters, all tests, both builds, and actionlint exit 0.

- [ ] **Step 3: Commit the reusable checks**

Run:

```bash
git add scripts
git commit -m "build(checks): add local verification entry point"
```

## Task 7: Add deterministic CI and pull-request policy

**Files:**

- Create: `.github/workflows/ci.yml`
- Create: `.github/workflows/pr.yml`

- [ ] **Step 1: Add CI with stable job names**

Create `ci.yml` with these jobs and exact names:

```yaml
name: CI

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]
  workflow_dispatch:

concurrency:
  group: ci-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: true

permissions:
  contents: read

jobs:
  quality:
    name: Quality
    runs-on: macos-26
    timeout-minutes: 15
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - run: swift format lint --recursive --strict Sources Tests Package.swift
      - run: swift package plugin --allow-writing-to-package-directory swiftlint --strict

  tests:
    name: Tests
    runs-on: macos-26
    timeout-minutes: 15
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - run: swift test

  build:
    name: Build
    runs-on: macos-26
    timeout-minutes: 15
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - run: swift build
      - run: swift build -c release

  workflows:
    name: Workflow lint
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - uses: raven-actions/actionlint@3d39aea434753780c3b3d4a1a31c854b4dbf49d7 # v2.2.0
        with:
          version: 1.7.12
```

- [ ] **Step 2: Add PR title and commit validation**

Create `pr.yml` with two stable jobs, `Title` and `Commits`. The title job
checks out the trusted base revision. The commit job checks out the pull
request's head SHA with full history for the commit range, but extracts the
validator from the trusted base revision before invoking it. The synthetic
merge subject is never validated, and a pull request cannot alter the
validator it uses. If the trusted base predates the validator, both jobs use a
literal bootstrap fallback identical to the script being introduced; later
pull requests use only the base-revision copy.

The workflow uses the trusted-base validator materialization described above.
Keep the bootstrap fallback literal identical to
`scripts/check-conventional-subject.sh`; the abbreviated shape is:

```yaml
concurrency:
  group: pr-${{ github.event.pull_request.number }}
  cancel-in-progress: true

jobs:
  title:
    steps:
      - uses: actions/checkout@... # pinned SHA
        with:
          ref: ${{ github.event.pull_request.base.sha }}
      - run: materialize trusted-base validator or the identical bootstrap rule
      - run: $RUNNER_TEMP/check-conventional-subject.sh "$PR_TITLE"

  commits:
    steps:
      - uses: actions/checkout@... # pinned SHA
        with:
          fetch-depth: 0
          ref: ${{ github.event.pull_request.head.sha }}
      - env:
          BASE_SHA: ${{ github.event.pull_request.base.sha }}
        run: materialize trusted-base validator or the identical bootstrap rule
      - run: apply the temporary validator to git log --format=%s "$BASE_SHA..HEAD"
```

- [ ] **Step 3: Validate and commit the workflows**

Run:

```bash
actionlint
scripts/check.sh
git add .github/workflows/ci.yml .github/workflows/pr.yml
git commit -m "ci(checks): enforce repository quality"
```

Expected: actionlint and the complete local check exit 0.

## Task 8: Add CodeQL, Dependabot, and release-please

**Files:**

- Create: `.github/workflows/codeql.yml`
- Create: `.github/workflows/release.yml`
- Create: `.github/dependabot.yml`
- Create: `release-please-config.json`
- Create: `.release-please-manifest.json`
- Create: `CHANGELOG.md`

- [ ] **Step 1: Add Swift CodeQL analysis**

Create `codeql.yml` using `github/codeql-action` commit
`e4fba868fa4b1b91e1fdab776edc8cfbe6e9fb81` (`v4`):

```yaml
name: CodeQL

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]
  schedule:
    - cron: "23 4 * * 1"
  workflow_dispatch:

concurrency:
  group: codeql-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: true

permissions:
  contents: read

jobs:
  analyze:
    name: Analyze (swift)
    runs-on: macos-26
    timeout-minutes: 30
    permissions:
      contents: read
      # CodeQL must upload Swift analysis results to code scanning.
      security-events: write
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - uses: github/codeql-action/init@e4fba868fa4b1b91e1fdab776edc8cfbe6e9fb81 # v4
        with:
          build-mode: manual
          languages: swift
          queries: security-extended
      - run: swift build
      - uses: github/codeql-action/analyze@e4fba868fa4b1b91e1fdab776edc8cfbe6e9fb81 # v4
        with:
          category: /language:swift
```

- [ ] **Step 2: Add grouped dependency updates**

Create `.github/dependabot.yml`:

```yaml
version: 2
updates:
  - package-ecosystem: swift
    directory: /
    schedule:
      interval: weekly
      day: monday
      time: "06:00"
      timezone: Europe/London
    open-pull-requests-limit: 5
    groups:
      swift-development:
        patterns:
          - "*"

  - package-ecosystem: github-actions
    directory: /
    schedule:
      interval: weekly
      day: monday
      time: "06:00"
      timezone: Europe/London
    open-pull-requests-limit: 5
    groups:
      actions:
        patterns:
          - "*"
```

- [ ] **Step 3: Configure release-please v5**

Create `.release-please-manifest.json`:

```json
{
  ".": "0.0.0"
}
```

The synthetic `0.0.0` root version is intentional: with
`bump-minor-pre-major: true`, the first feature release becomes `0.1.0`.
Release-please does not use an `initial-version` setting in this configuration.

Create `CHANGELOG.md`:

```markdown
# Changelog

Notable changes to `clamshellctl` are recorded here by release-please.
```

Create `release-please-config.json`:

```json
{
  "$schema": "https://raw.githubusercontent.com/googleapis/release-please/main/schemas/config.json",
  "packages": {
    ".": {
      "release-type": "simple",
      "package-name": "clamshellctl",
      "include-v-in-tag": true,
      "include-component-in-tag": false,
      "bump-minor-pre-major": true,
      "bump-patch-for-minor-pre-major": false,
      "extra-files": [
        {
          "type": "generic",
          "path": "Sources/ClamshellCore/BuildVersion.swift"
        }
      ],
      "changelog-sections": [
        {"type": "feat", "section": "Features"},
        {"type": "fix", "section": "Fixes"},
        {"type": "perf", "section": "Performance"},
        {"type": "docs", "section": "Documentation"},
        {"type": "test", "section": "Tests", "hidden": true},
        {"type": "build", "section": "Build", "hidden": true},
        {"type": "ci", "section": "CI", "hidden": true},
        {"type": "refactor", "section": "Refactoring", "hidden": true},
        {"type": "style", "section": "Style", "hidden": true},
        {"type": "chore", "section": "Chores", "hidden": true}
      ]
    }
  }
}
```

Create `release.yml` using
`googleapis/release-please-action@45996ed1f6d02564a971a2fa1b5860e934307cf7`
(`v5`):

```yaml
name: Release

on:
  push:
    branches: [main]
  workflow_dispatch:

concurrency:
  group: release-${{ github.ref }}
  cancel-in-progress: true

permissions: {}

jobs:
  release-please:
    name: Release Please
    runs-on: ubuntu-latest
    timeout-minutes: 10
    permissions:
      # release-please opens release PRs, updates release metadata, and creates releases.
      contents: write
      issues: write
      pull-requests: write
    steps:
      - uses: googleapis/release-please-action@45996ed1f6d02564a971a2fa1b5860e934307cf7 # v5
        with:
          token: ${{ secrets.RELEASE_PLEASE_TOKEN || secrets.GITHUB_TOKEN }}
          config-file: release-please-config.json
          manifest-file: .release-please-manifest.json
```

Do not add DMG upload until issue #6 supplies the packaging script.

- [ ] **Step 4: Validate and commit automation**

Run:

```bash
actionlint
python3 -m json.tool release-please-config.json >/dev/null
python3 -m json.tool .release-please-manifest.json >/dev/null
scripts/check.sh
git add .github CHANGELOG.md release-please-config.json .release-please-manifest.json
git commit -m "ci(release): add security and release automation"
```

Expected: workflow and JSON validation pass; the local quality gate passes.

## Task 9: Complete public repository documentation

**Files:**

- Create: `.github/CODEOWNERS`
- Create: `.github/CODE_OF_CONDUCT.md`
- Create: `.github/CONTRIBUTING.md`
- Create: `.github/SECURITY.md`
- Create: `.github/SUPPORT.md`
- Create: `.github/pull_request_template.md`
- Create: `.github/ISSUE_TEMPLATE/config.yml`
- Modify: `.github/ISSUE_TEMPLATE/bug.yml`
- Modify: `.github/ISSUE_TEMPLATE/feature.yml`
- Modify: `README.md`
- Modify: `docs/clamshellctl-design.md`
- Modify: `docs/implementation-plan.md`

- [ ] **Step 1: Add ownership and contribution policy**

Use this CODEOWNERS rule:

```text
* @LMLiam
```

`CONTRIBUTING.md` must contain exact sections for prerequisites, setup,
`scripts/check.sh`, Google Swift style, the one-primary-responsibility file
rule, `verb(area): description`, pull requests, behavioural testing, and
security reporting. It must state that SwiftLint suppressions require a local
reason and that contributors must not run privileged tests against live system
paths.

Use Contributor Covenant 2.1 unchanged except for replacing its enforcement
contact placeholder with `https://github.com/LMLiam`. This intentional
substitution avoids publishing a personal email address.

- [ ] **Step 2: Add security and support policy**

`SECURITY.md` must define supported versions as the latest release, direct
vulnerabilities to GitHub private vulnerability reporting, prohibit public
proofs containing secrets or destructive commands, promise acknowledgement
within seven days, and describe the privileged helper, sudoers policy, and
unsigned distribution as security-sensitive surfaces.

`SUPPORT.md` must direct bugs to the bug form, feature proposals to the feature
form, security reports to private vulnerability reporting, and macOS or
Homebrew usage questions to a normal GitHub issue without promising individual
support.

- [ ] **Step 3: Add issue and pull-request guidance**

Set `blank_issues_enabled: false`. Add contact links for private security
reporting and support. Keep the current bug and feature forms, but make their
required fields and labels consistent with `type: bug` and `type: feature`.

The pull-request template must include summary, linked issues, behaviour and
security impact, verification commands, screenshots only when UI changes, and
a checklist covering `scripts/check.sh`, documentation, and scoped commit
subjects. Start it with a single top-level `# Summary` heading.

- [ ] **Step 4: Align public and internal documentation**

Add CI and CodeQL badges and contributor links to `README.md`. Update the source
trees in `clamshellctl-design.md` and `implementation-plan.md` to match the
responsibility folders. Replace direct formatter-only verification commands
with `scripts/check.sh` where the full quality gate is intended. Preserve issue
#10's rule that the `LMLiam/LMLiam` profile README changes only after the first
public release succeeds.

- [ ] **Step 5: Verify and commit documentation**

Run:

```bash
scripts/check.sh
git diff --check
git add .github README.md docs
git commit -m "docs(community): complete repository guidance"
```

Expected: all checks pass and no generated or `.vscode/` file is staged.

## Task 10: Run the complete local verification and push the branch

**Files:** None beyond corrections required by the checks.

- [ ] **Step 1: Run the quality gate from a clean build state**

Run:

```bash
swift package clean
scripts/check.sh
git diff --check
git status --short
```

Expected: all checks pass; only `.vscode/` remains untracked.

- [ ] **Step 2: Inspect every commit subject**

Run:

```bash
while IFS= read -r subject; do
  scripts/check-conventional-subject.sh "$subject"
done < <(git log --format=%s origin/main..HEAD)
```

Expected: each subject exits 0. Do not rewrite the historical GitGuardian
fixture commit.

- [ ] **Step 3: Push the existing feature branch**

Run:

```bash
git push origin feat/mvp
```

Expected: draft PR #11 updates and CI, PR, CodeQL, GitGuardian, and CodeRabbit
checks appear. Keep the PR in draft while repository configuration is applied.

## Task 11: Resolve GitGuardian and enable repository features

**Files:** None.

- [ ] **Step 1: Resolve only the false-positive incident**

Open the failing `GitGuardian Security Checks` details for PR #11. Select the
historical occurrence in `Tests/ClamshellCoreTests/SudoersPolicyTests.swift` and
choose `Skip: false positive`. Do not select a path ignore, detector ignore,
test-credential classification, or history rewrite.

Verify:

```bash
gh pr checks 11 --repo LMLiam/clamshellctl
```

Expected: `GitGuardian Security Checks` is successful.

- [ ] **Step 2: Apply repository merge and feature settings**

Run:

```bash
gh repo edit LMLiam/clamshellctl \
  --description "Control battery clamshell mode on macOS" \
  --enable-issues=true \
  --enable-projects=false \
  --enable-wiki=false \
  --enable-merge-commit=false \
  --enable-rebase-merge=false \
  --enable-squash-merge=true \
  --delete-branch-on-merge \
  --add-topic battery \
  --add-topic clamshell-mode \
  --add-topic command-line-tool \
  --add-topic control-center \
  --add-topic macos \
  --add-topic swift \
  --add-topic widgetkit
```

- [ ] **Step 3: Enable available security features**

Run:

```bash
gh api --method PUT repos/LMLiam/clamshellctl/vulnerability-alerts
gh api --method PUT repos/LMLiam/clamshellctl/automated-security-fixes
gh api --method PUT repos/LMLiam/clamshellctl/private-vulnerability-reporting
gh api --method PATCH repos/LMLiam/clamshellctl \
  -f 'security_and_analysis[secret_scanning][status]=enabled' \
  -f 'security_and_analysis[secret_scanning_push_protection][status]=enabled'
```

Expected: each request succeeds. If GitHub reports that a public-repository
feature is already enabled, verify its state and continue without weakening it.

- [ ] **Step 4: Curate labels without duplicating existing taxonomy**

Keep the current `area:*`, `type:*`, `good first issue`, `help wanted`, and
`question` labels. Remove redundant default `bug`, `documentation`, and
`enhancement` labels after confirming no issue uses them. Add:

```text
priority: high    B60205
priority: medium  FBCA04
priority: low     0E8A16
status: blocked   D93F0B
status: ready     0E8A16
status: in review 5319E7
```

Keep milestone `v0.1.0` and all current issue assignments. Mark issues #1-#3
`status: in review`; do not close them before PR #11 merges. Issue #8 remains
open because native-app and DMG release jobs depend on issues #5 and #6.

## Task 12: Create the protected-main ruleset

**Files:** None.

- [ ] **Step 1: Wait for every required check name to exist**

Run:

```bash
gh pr checks 11 --repo LMLiam/clamshellctl
```

Expected check names:

```text
Quality
Tests
Build
Workflow lint
Title
Commits
Analyze (swift)
GitGuardian Security Checks
```

Do not create the ruleset while any name is absent.

- [ ] **Step 2: Create the active default-branch ruleset**

Use `gh api --method POST repos/LMLiam/clamshellctl/rulesets --input -` with a
JSON body that contains:

```json
{
  "name": "Main",
  "target": "branch",
  "enforcement": "active",
  "bypass_actors": [
    {
      "actor_id": 5,
      "actor_type": "RepositoryRole",
      "bypass_mode": "always"
    }
  ],
  "conditions": {
    "ref_name": {
      "exclude": [],
      "include": ["~DEFAULT_BRANCH"]
    }
  },
  "rules": [
    {"type": "deletion"},
    {"type": "non_fast_forward"},
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 1,
        "dismiss_stale_reviews_on_push": true,
        "required_reviewers": [],
        "require_code_owner_review": true,
        "require_last_push_approval": false,
        "required_review_thread_resolution": true,
        "allowed_merge_methods": ["squash"]
      }
    },
    {
      "type": "code_scanning",
      "parameters": {
        "code_scanning_tools": [
          {
            "tool": "CodeQL",
            "security_alerts_threshold": "medium_or_higher",
            "alerts_threshold": "errors"
          }
        ]
      }
    },
    {
      "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": true,
        "do_not_enforce_on_create": false,
        "required_status_checks": [
          {"context": "Quality"},
          {"context": "Tests"},
          {"context": "Build"},
          {"context": "Workflow lint"},
          {"context": "Title"},
          {"context": "Commits"},
          {"context": "GitGuardian Security Checks"}
        ]
      }
    }
  ]
}
```

This requires one maintainer/code-owner approval. Repository-role ID `5`
retains the administrator bypass Liam chose for his own pull requests.

- [ ] **Step 3: Verify repository state**

Run:

```bash
gh api repos/LMLiam/clamshellctl/rulesets
readonly repository_fields="deleteBranchOnMerge,hasProjectsEnabled,hasWikiEnabled"
repository_fields+=",mergeCommitAllowed,rebaseMergeAllowed,squashMergeAllowed"
repository_fields+=",repositoryTopics"
gh repo view LMLiam/clamshellctl \
  --json "$repository_fields"
```

Expected: active `Main` ruleset, squash-only merging, automatic branch deletion,
projects and wiki disabled, and all seven topics present.

## Task 13: Final review and pull-request handoff

**Files:** Any narrow correction required by review.

- [ ] **Step 1: Run final verification**

Run:

```bash
scripts/check.sh
gh pr checks 11 --repo LMLiam/clamshellctl
git status --short --branch
```

Expected: local checks and every required remote check pass; `.vscode/` remains
the only untracked path.

- [ ] **Step 2: Review the complete branch diff**

Review:

```bash
git diff --stat origin/main...HEAD
git diff --check origin/main...HEAD
```

Confirm that no user-visible CLI behaviour, privileged command, installation
path, permission, or exit code changed accidentally. Run the configured code
review workflow and resolve only evidence-backed findings.

- [ ] **Step 3: Update the existing draft PR**

Keep PR #11's valid title unless the final scope requires a more accurate
`feat(area): description` title. Update its body with:

```text
- Google Swift style enforced by swift-format and SwiftLint
- Responsibility-based source and test layout
- CI, CodeQL, release-please, and Dependabot
- Community health and repository security configuration
- GitGuardian false positive resolved without weakening scanning
```

Keep `Closes #1`, `Closes #2`, and `Closes #3`. Do not add `Closes #8` because
its native-app and DMG acceptance criteria remain outstanding. Leave the pull
request in draft for Liam's final review; he can make it ready or use the
administrator merge bypass after reviewing the complete result.

- [ ] **Step 4: Report the handoff**

Provide Liam with the PR URL, commit list, local and remote verification results,
the ruleset URL, and the still-open issue list. State explicitly that the
profile README remains assigned to issue #10 after the first public release.
