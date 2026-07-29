# Contributing

## Prerequisites

You need macOS, Xcode 26.6 or later, and Swift 6.3 or later. You also need
SwiftLint 0.65.0 and [actionlint](https://github.com/rhysd/actionlint).
Install the development tools with:

```bash
brew install actionlint swiftlint
```

The future companion app also requires
[XcodeGen](https://github.com/yonaskolb/XcodeGen).

## Setup

Fork the repository, clone your fork, and create a branch from `main`. Resolve
the package dependencies once after cloning:

```bash
swift package resolve
```

Do not run tests against live privileged paths. Tests must use fake process and
filesystem boundaries; they must never change `pmset`, invoke `sudo`, or write
to `/Library/PrivilegedHelperTools` or `/etc/sudoers.d`.

## Checks

Run the complete local gate before each pull request:

```bash
scripts/check.sh
```

The script checks formatting, SwiftLint, tests, debug and release builds, and
GitHub Actions workflows. When native app targets exist, it also generates and
builds the Xcode project without code signing.

## Swift style

Follow the [Google Swift Style Guide](https://google.github.io/swift/).
`swift-format` owns formatting; SwiftLint owns semantic and maintainability
rules. Prefer self-describing names. Add comments only for contracts,
constraints, or decisions that the code does not make clear.

Keep one primary responsibility per file. A private helper may remain beside
its sole consumer. Do not create generic `Utils`, `Common`, or `Models`
directories.

Fix lint findings in code where practical. A SwiftLint suppression must have a
narrow scope and an adjacent explanation of why the rule does not apply.

## Commits

Every commit and pull-request title must use:

```text
verb(area): description
```

Examples include `feat(status): report battery state` and
`fix(setup): preserve an existing sudoers policy`. The accepted verbs are
`feat`, `fix`, `docs`, `test`, `build`, `ci`, `refactor`, `perf`, `style`,
`chore`, and `revert`.

Dependency updates use `build(deps): ...` so they remain within the accepted
commit vocabulary and are hidden from the public changelog.

## Tests

Test observable behaviour through public or internal boundaries. Cover failure
paths and privilege constraints. Avoid assertions about private implementation
details, mock call order unless order is part of the contract, and live system
mutation.

## Pull requests

Keep each pull request focused and link the issue it addresses. Describe any
change to command output, exit status, system paths, permissions, sudoers
policy, or the helper allow-list. Include the commands you ran and update user
documentation when behaviour changes.

Maintainer approval and all required checks are needed before merge. The
repository uses squash merging, so the pull-request title becomes the release
commit subject.

## Security

Do not report vulnerabilities in a public issue. Follow the private reporting
instructions in [SECURITY.md](SECURITY.md).
