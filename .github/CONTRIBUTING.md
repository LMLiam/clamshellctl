# Contributing

## Prerequisites

You need macOS, Xcode 26.6 or later, and Swift 6.3 or later. You also need
XcodeGen 2.46.0, SwiftLint 0.65.0, actionlint 1.7.12, Node.js, and npm.
Install the development tools with:

```bash
brew install actionlint node swiftlint xcodegen
```

## Setup

Fork the repository, clone your fork, and create a branch from `main`. Generate
the Xcode project and resolve the package dependencies after cloning:

```bash
xcodegen generate
swift package resolve
```

Do not commit `Clamshell.xcodeproj`. XcodeGen creates it from `project.yml`.

Do not run tests against live privileged paths. Tests must use fake process and
filesystem boundaries; they must never change `pmset`, invoke `sudo`, or write
to `/Library/PrivilegedHelperTools` or `/etc/sudoers.d`.

## Checks

Run the complete local gate before each pull request:

```bash
scripts/check.sh
npx --yes markdownlint-cli2 '**/*.md' '#.build'
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

## Documentation style

Use ASD-STE100 Simplified Technical English for all documentation. Use British
English spelling. Use short sentences and active voice. Give one instruction
in each sentence. Use one term for each item or action.

You can use an unapproved term when technical accuracy requires it. Examples
include product names, commands, code identifiers, API names, quoted interface
text, and standard names. Do not replace a precise technical term with an
ambiguous word.

Keep guides in `docs/`. Keep standard community files in `.github/`. Do not
commit AI plans or internal process notes. The repository ignores
`docs/plans/`.

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

A maintainer must approve the pull request before merge, and all required
checks must pass. The repository uses squash merging, so the pull-request title
becomes the release commit subject.

## Security

Do not report vulnerabilities in a public issue. Follow the private reporting
instructions in [SECURITY.md](SECURITY.md).
