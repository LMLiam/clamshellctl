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
