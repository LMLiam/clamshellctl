#!/bin/bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly repository_root
readonly packaging_library="$repository_root/scripts/lib/dmg-packaging.sh"
readonly embed_script="$repository_root/scripts/embed-command-products.sh"
readonly package_script="$repository_root/scripts/package-dmg.sh"
temporary_root=""

cleanup() {
  [[ -n "$temporary_root" ]] || return 0
  hdiutil detach -force "$temporary_root/mount" >/dev/null 2>&1 || true
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

write_info_plist() {
  local path="$1"
  local identifier="$2"
  local executable="$3"
  local package_type="$4"

  cat >"$path" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$executable</string>
  <key>CFBundleIdentifier</key>
  <string>$identifier</string>
  <key>CFBundlePackageType</key>
  <string>$package_type</string>
  <key>CFBundleShortVersionString</key>
  <string>1.2.3</string>
  <key>CFBundleVersion</key>
  <string>1</string>
</dict>
</plist>
PLIST
}

compile_universal_executable() {
  local output="$1"
  local source="$output.c"

  printf 'int main(void) { return 0; }\n' >"$source"

  xcrun clang \
    -arch arm64 \
    -arch x86_64 \
    -o "$output" \
    "$source"
  rm "$source"
}

create_fixture() {
  local fixture_root="$1"
  local app="$fixture_root/Clamshell.app"
  local extension="$app/Contents/PlugIns/ClamshellControl.appex"

  mkdir -p \
    "$app/Contents/MacOS" \
    "$app/Contents/Resources" \
    "$extension/Contents/MacOS"
  write_info_plist \
    "$app/Contents/Info.plist" \
    "uk.co.lmliam.clamshell.fixture" \
    "Clamshell" \
    "APPL"
  write_info_plist \
    "$extension/Contents/Info.plist" \
    "uk.co.lmliam.clamshell.fixture.control" \
    "ClamshellControl" \
    "XPC!"
  compile_universal_executable "$app/Contents/MacOS/Clamshell"
  compile_universal_executable "$extension/Contents/MacOS/ClamshellControl"
  compile_universal_executable "$fixture_root/clamshellctl"
  compile_universal_executable "$fixture_root/clamshellctl-helper"
  cat >"$fixture_root/control-entitlements.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.app-sandbox</key>
  <true/>
</dict>
</plist>
PLIST
  codesign \
    --force \
    --sign - \
    --entitlements "$fixture_root/control-entitlements.plist" \
    "$extension"
  codesign --force --sign - "$app"
}

attach_dmg() {
  local dmg="$1"
  local mount_point="$2"
  local output

  mkdir -p "$mount_point"
  if ! output="$(hdiutil attach \
    -readonly \
    -nobrowse \
    -mountpoint "$mount_point" \
    "$dmg" 2>&1)"; then
    fail "could not attach $dmg: $output"
  fi
}

run_tests() {
  [[ -f "$packaging_library" ]] || fail "missing $packaging_library"
  # shellcheck source=/dev/null
  source "$packaging_library"

  temporary_root="$(mktemp -d "${TMPDIR:-/tmp}/clamshellctl-dmg-tests.XXXXXX")"
  trap cleanup EXIT

  create_fixture "$temporary_root/fixture"
  mkdir -p "$temporary_root/output"

  assert_fails \
    "version must use MAJOR.MINOR.PATCH" \
    bash "$package_script" "v1.2.3" "$temporary_root/output"
  assert_fails \
    "CLI payload is not a regular file" \
    bash "$embed_script" \
    "$temporary_root/fixture/Clamshell.app" \
    "$temporary_root/fixture/missing-cli" \
    "$temporary_root/fixture/clamshellctl-helper"
  assert_fails \
    "helper payload is not a regular file" \
    bash "$embed_script" \
    "$temporary_root/fixture/Clamshell.app" \
    "$temporary_root/fixture/clamshellctl" \
    "$temporary_root/fixture/missing-helper"

  local missing_extension_app="$temporary_root/missing-extension.app"
  ditto "$temporary_root/fixture/Clamshell.app" "$missing_extension_app"
  rm -r "$missing_extension_app/Contents/PlugIns/ClamshellControl.appex"
  assert_fails \
    "control extension is missing" \
    bash "$embed_script" \
    "$missing_extension_app" \
    "$temporary_root/fixture/clamshellctl" \
    "$temporary_root/fixture/clamshellctl-helper"

  local thin_cli="$temporary_root/thin-clamshellctl"
  xcrun clang -arch arm64 -x c -o "$thin_cli" - <<'SOURCE'
int main(void) { return 0; }
SOURCE
  assert_fails \
    "CLI payload must contain arm64 and x86_64" \
    bash "$embed_script" \
    "$temporary_root/fixture/Clamshell.app" \
    "$thin_cli" \
    "$temporary_root/fixture/clamshellctl-helper"

  local packaged_app="$temporary_root/packaged/Clamshell.app"
  mkdir -p "$(dirname "$packaged_app")"
  ditto "$temporary_root/fixture/Clamshell.app" "$packaged_app"
  bash "$embed_script" \
    "$packaged_app" \
    "$temporary_root/fixture/clamshellctl" \
    "$temporary_root/fixture/clamshellctl-helper"

  local embedded_entitlements="$temporary_root/embedded-entitlements.plist"
  codesign \
    --display \
    --entitlements :- \
    "$packaged_app/Contents/PlugIns/ClamshellControl.appex" \
    >"$embedded_entitlements" 2>/dev/null
  [[ "$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.app-sandbox' "$embedded_entitlements")" == "true" ]] ||
    fail "embedding removed the control extension sandbox entitlement"

  # The sourced verifier invokes this test double.
  # shellcheck disable=SC2329
  codesign() {
    if [[ "$1" == "--display" ]]; then
      echo "Signature=Developer ID Application"
      return 0
    fi
    command codesign "$@"
  }
  assert_fails \
    "CLI payload must use an ad hoc signature" \
    verify_ad_hoc_signature \
    "CLI payload" \
    "$packaged_app/Contents/MacOS/clamshellctl"
  unset -f codesign

  local invalid_signature_cli="$temporary_root/invalid-signature-clamshellctl"
  ditto "$temporary_root/fixture/clamshellctl" "$invalid_signature_cli"
  codesign --force --sign - "$invalid_signature_cli"
  printf 'invalid' >>"$invalid_signature_cli"
  assert_fails \
    "CLI payload has an invalid signature" \
    verify_ad_hoc_signature \
    "CLI payload" \
    "$invalid_signature_cli"

  printf 'invalid' >>"$packaged_app/Contents/Resources/clamshellctl-helper"
  assert_fails \
    "helper payload has an invalid signature" \
    create_release_dmg \
    "1.2.3" \
    "$temporary_root/output" \
    "$packaged_app"

  ditto "$temporary_root/fixture/clamshellctl-helper" \
    "$packaged_app/Contents/Resources/clamshellctl-helper"
  sign_app_bundle "$packaged_app"

  local outside_artifact="$temporary_root/outside.dmg"
  ln -s "$outside_artifact" "$temporary_root/output/clamshellctl-v1.2.3.dmg"
  assert_fails \
    "output path must stay inside the output directory" \
    create_release_dmg \
    "1.2.3" \
    "$temporary_root/output" \
    "$packaged_app"
  rm "$temporary_root/output/clamshellctl-v1.2.3.dmg"

  create_release_dmg "1.2.3" "$temporary_root/output" "$packaged_app"

  local dmg="$temporary_root/output/clamshellctl-v1.2.3.dmg"
  local checksum="$dmg.sha256"
  [[ -f "$dmg" ]] || fail "release DMG was not created"
  [[ -f "$checksum" ]] || fail "release checksum was not created"
  hdiutil verify "$dmg" >/dev/null
  if spctl \
    --assess \
    --type open \
    --context context:primary-signature \
    "$dmg" >/dev/null 2>&1; then
    fail "unnotarised DMG was accepted by Gatekeeper"
  fi
  (
    cd "$temporary_root/output"
    shasum -a 256 -c "$(basename "$checksum")" >/dev/null
  )
  [[ "$(cat "$checksum")" == *"  $(basename "$dmg")" ]] ||
    fail "checksum must contain only the DMG basename"
  [[ "$(cat "$checksum")" != *"$temporary_root"* ]] ||
    fail "checksum contains a local path"

  attach_dmg "$dmg" "$temporary_root/mount"
  [[ -d "$temporary_root/mount/Clamshell.app" ]] ||
    fail "DMG does not contain Clamshell.app"
  [[ -L "$temporary_root/mount/Applications" ]] ||
    fail "DMG does not contain the Applications symlink"
  [[ "$(readlink "$temporary_root/mount/Applications")" == "/Applications" ]] ||
    fail "Applications symlink has the wrong target"
  local entry_count
  entry_count="$(find "$temporary_root/mount" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')"
  [[ "$entry_count" == "2" ]] || fail "DMG must contain exactly two entries"

  echo "All DMG packaging tests passed."
}

run_tests
