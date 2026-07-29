#!/bin/bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly repository_root
readonly version_library="$repository_root/scripts/lib/version-consistency.sh"
temporary_root=""

cleanup() {
  [[ -n "$temporary_root" ]] || return 0
  rm -rf "$temporary_root" || true
}

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local expected="$1"
  local actual="$2"

  [[ "$actual" == *"$expected"* ]] ||
    fail "expected output to contain '$expected', got: $actual"
}

assert_fails() {
  local expected="$1"
  shift

  local output
  if output="$("$@" 2>&1)"; then
    fail "expected command to fail: $*"
  fi
  assert_contains "$expected" "$output"
}

create_fixture() {
  local name="$1"
  local fixture="$temporary_root/$name"

  mkdir -p \
    "$fixture/App/ClamshellApp" \
    "$fixture/App/ClamshellControl" \
    "$fixture/Sources/ClamshellCore"
  printf '0.1.0\n' >"$fixture/version.txt"
  cat >"$fixture/Sources/ClamshellCore/BuildVersion.swift" <<'SWIFT'
public enum BuildVersion {
  // x-release-please-version
  public static let current = "0.1.0"
}
SWIFT
  cat >"$fixture/project.yml" <<'YAML'
settings:
  base:
    # x-release-please-version
    MARKETING_VERSION: "0.1.0"
YAML
  cat >"$fixture/.release-please-manifest.json" <<'JSON'
{".":"0.1.0"}
JSON
  cat >"$fixture/release-please-config.json" <<'JSON'
{
  "packages": {
    ".": {
      "release-type": "simple",
      "extra-files": [
        {
          "type": "generic",
          "path": "Sources/ClamshellCore/BuildVersion.swift"
        },
        {
          "type": "generic",
          "path": "project.yml"
        }
      ]
    }
  }
}
JSON
  cat >"$fixture/App/ClamshellApp/Info.plist" <<'PLIST'
<plist version="1.0">
<dict>
  <key>CFBundleShortVersionString</key>
  <string>$(MARKETING_VERSION)</string>
</dict>
</plist>
PLIST
  cp \
    "$fixture/App/ClamshellApp/Info.plist" \
    "$fixture/App/ClamshellControl/Info.plist"
  printf '%s\n' "$fixture"
}

run_tests() {
  [[ -f "$version_library" ]] || fail "missing $version_library"
  # shellcheck source=/dev/null
  source "$version_library"

  temporary_root="$(mktemp -d "${TMPDIR:-/tmp}/clamshellctl-version-tests.XXXXXX")"
  trap cleanup EXIT

  local aligned_fixture
  aligned_fixture="$(create_fixture aligned)"
  check_version_consistency "$aligned_fixture" >/dev/null ||
    fail "an aligned fixture failed validation"

  local cli_drift_fixture
  cli_drift_fixture="$(create_fixture cli-drift)"
  sed -i '' 's/current = "0.1.0"/current = "0.2.0"/' \
    "$cli_drift_fixture/Sources/ClamshellCore/BuildVersion.swift"
  assert_fails \
    "CLI version must be 0.1.0: 0.2.0" \
    check_version_consistency \
    "$cli_drift_fixture"

  local app_drift_fixture
  app_drift_fixture="$(create_fixture app-drift)"
  sed -i '' 's/MARKETING_VERSION: "0.1.0"/MARKETING_VERSION: "0.2.0"/' \
    "$app_drift_fixture/project.yml"
  assert_fails \
    "app version must be 0.1.0: 0.2.0" \
    check_version_consistency \
    "$app_drift_fixture"

  local manifest_drift_fixture
  manifest_drift_fixture="$(create_fixture manifest-drift)"
  printf '{".":"0.2.0"}\n' \
    >"$manifest_drift_fixture/.release-please-manifest.json"
  assert_fails \
    "release manifest version must be 0.1.0: 0.2.0" \
    check_version_consistency \
    "$manifest_drift_fixture"

  local static_plist_fixture
  static_plist_fixture="$(create_fixture static-plist)"
  sed -i '' "s/\$(MARKETING_VERSION)/0.1.0/" \
    "$static_plist_fixture/App/ClamshellControl/Info.plist"
  assert_fails \
    "control extension version must use \$(MARKETING_VERSION)" \
    check_version_consistency \
    "$static_plist_fixture"

  local release_config_fixture
  release_config_fixture="$(create_fixture release-config)"
  jq \
    '.packages["."]."extra-files"
      |= map(select((if type == "string" then . else .path end) != "project.yml"))' \
    "$release_config_fixture/release-please-config.json" \
    >"$release_config_fixture/release-please-config.updated.json"
  mv \
    "$release_config_fixture/release-please-config.updated.json" \
    "$release_config_fixture/release-please-config.json"
  assert_fails \
    "release configuration must update project.yml" \
    check_version_consistency \
    "$release_config_fixture"

  local malformed_fixture
  malformed_fixture="$(create_fixture malformed)"
  printf '01.0.0\n' >"$malformed_fixture/version.txt"
  assert_fails \
    "version.txt must use MAJOR.MINOR.PATCH" \
    check_version_consistency \
    "$malformed_fixture"

  echo "All version consistency tests passed."
}

run_tests
