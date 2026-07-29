#!/bin/bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly repository_root
cd "$repository_root"

swift_paths=(Package.swift Sources Tests)
if [[ -d App ]]; then
  swift_paths+=(App)
fi

command -v swiftlint >/dev/null || {
  echo "SwiftLint is required: brew install swiftlint" >&2
  exit 1
}
[[ "$(swiftlint version)" == "0.65.0" ]] || {
  echo "SwiftLint 0.65.0 is required" >&2
  exit 1
}

swift format lint --recursive --strict "${swift_paths[@]}"
swiftlint lint --strict
swift test
swift build
swift build -c release
bash Tests/Scripts/run-dmg-packaging-tests.sh

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
