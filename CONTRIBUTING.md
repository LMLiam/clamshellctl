# Contributing

Thank you for helping with `clamshellctl`.

## Before you start

- Use a bug report for incorrect behaviour.
- Use a feature request to explain a user problem before you propose a large
  change.
- Use private vulnerability reporting for a security problem.
- Keep each pull request focused on one issue.

## Development requirements

You need:

- macOS
- Xcode 26.6 or later
- Swift 6.3 or later
- XcodeGen 2.46.0
- SwiftLint 0.65.0
- actionlint 1.7.12
- Node.js and npm for Markdown checks

Clone the repository and generate the Xcode project:

```bash
git clone https://github.com/LMLiam/clamshellctl.git
cd clamshellctl
xcodegen generate
```

Do not commit `Clamshell.xcodeproj`. XcodeGen creates it from `project.yml`.

## Code structure

Put each file in the directory that owns its responsibility. Do not put a file
in a directory only because another type uses it.

Prefer one primary top-level Swift declaration per file. Small private support
declarations can stay with the primary declaration when this makes the code
easier to read. Use clear names instead of comments that repeat the code. Add a
comment only when it explains a constraint, security reason, or non-obvious
decision.

Follow the
[Google Swift Style Guide](https://google.github.io/swift/). The repository
uses Swift Format, SwiftLint, and `.editorconfig` to enforce its local rules.

## Documentation

Write all user and contributor documentation in ASD-STE100 Simplified
Technical English. You can use required product names, command names, API
names, file paths, and other technical terms.

Keep documentation in `docs/` unless it is a standard repository file such as
`README.md`, `CONTRIBUTING.md`, `SECURITY.md`, or `SUPPORT.md`. Do not commit AI
plans or internal process notes. The repository ignores `docs/plans/`.

## Tests

Add a failing behavioural test before you change production behaviour. Tests
must not change the live power state or install privileged files.

Run the full check before you open a pull request:

```bash
scripts/check.sh
npx --yes markdownlint-cli2 '**/*.md' '#.build'
```

The check runs format validation, SwiftLint, tests, debug and release builds,
DMG packaging tests, workflow lint, and an Xcode app build.

## Commits and pull requests

Use this subject format for every commit and pull request:

```text
verb(area): description
```

Use a supported verb such as `feat`, `fix`, `docs`, `test`, `build`, `ci`,
`refactor`, or `chore`. Use a lower-case area. Do not add a full stop at the end
of the subject.

Complete the pull request template. Link the issue, describe behaviour and
security effects, and list the commands that you ran. Mark the pull request
ready for review only when it is ready for CodeRabbit and maintainer review.

A maintainer must approve a pull request before merge. Repository owners can
use an administrator merge for their own pull requests.
