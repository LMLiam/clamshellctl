#!/bin/bash

dmg_error() {
  echo "error: $*" >&2
  return 1
}

validate_release_version() {
  local version="$1"

  [[ "$version" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] ||
    dmg_error "version must use MAJOR.MINOR.PATCH without a v prefix: $version"
}

require_regular_file() {
  local description="$1"
  local path="$2"

  [[ -f "$path" && ! -L "$path" ]] ||
    dmg_error "$description is not a regular file: $path"
}

require_directory() {
  local description="$1"
  local path="$2"

  [[ -d "$path" && ! -L "$path" ]] ||
    dmg_error "$description is missing: $path"
}

verify_universal_executable() {
  local description="$1"
  local path="$2"

  require_regular_file "$description" "$path" || return
  lipo "$path" -verify_arch arm64 x86_64 >/dev/null 2>&1 ||
    dmg_error "$description must contain arm64 and x86_64: $path"
}

is_ad_hoc_signed() {
  local path="$1"
  local details

  details="$(codesign --display --verbose=4 "$path" 2>&1)" || return
  [[ "$details" == *"Signature=adhoc"* ]]
}

verify_ad_hoc_signature() {
  local description="$1"
  local path="$2"

  codesign --verify --strict "$path" >/dev/null 2>&1 ||
    dmg_error "$description has an invalid signature: $path" || return
  is_ad_hoc_signed "$path" ||
    dmg_error "$description must use an ad hoc signature: $path"
}

verify_app_layout() {
  local app="$1"

  require_directory "app bundle" "$app" || return
  require_directory \
    "control extension" \
    "$app/Contents/PlugIns/ClamshellControl.appex" || return
  verify_universal_executable \
    "app executable" \
    "$app/Contents/MacOS/Clamshell" || return
  verify_universal_executable \
    "control extension executable" \
    "$app/Contents/PlugIns/ClamshellControl.appex/Contents/MacOS/ClamshellControl"
}

verify_embedded_payloads() {
  local app="$1"

  verify_universal_executable \
    "CLI payload" \
    "$app/Contents/MacOS/clamshellctl" || return
  verify_universal_executable \
    "helper payload" \
    "$app/Contents/Resources/clamshellctl-helper"
}

sign_app_bundle() {
  local app="$1"
  local extension="$app/Contents/PlugIns/ClamshellControl.appex"
  local cli="$app/Contents/MacOS/clamshellctl"
  local helper="$app/Contents/Resources/clamshellctl-helper"

  verify_app_layout "$app" || return
  verify_embedded_payloads "$app" || return

  chmod 0755 "$cli" "$helper" ||
    dmg_error "could not make command payloads executable" || return
  codesign --force --sign - "$cli" >/dev/null ||
    dmg_error "could not sign CLI payload: $cli" || return
  codesign --force --sign - "$helper" >/dev/null ||
    dmg_error "could not sign helper payload: $helper" || return
  codesign \
    --force \
    --sign - \
    --preserve-metadata=entitlements,requirements,flags \
    "$extension" >/dev/null ||
    dmg_error "could not sign control extension: $extension" || return
  codesign \
    --force \
    --sign - \
    --preserve-metadata=entitlements,requirements,flags \
    "$app" >/dev/null ||
    dmg_error "could not sign app bundle: $app"
}

verify_packaged_app() {
  local app="$1"
  local extension="$app/Contents/PlugIns/ClamshellControl.appex"

  verify_app_layout "$app" || return
  verify_embedded_payloads "$app" || return
  verify_ad_hoc_signature "CLI payload" "$app/Contents/MacOS/clamshellctl" || return
  verify_ad_hoc_signature \
    "helper payload" \
    "$app/Contents/Resources/clamshellctl-helper" || return
  verify_ad_hoc_signature "control extension" "$extension" || return
  verify_ad_hoc_signature "app" "$app" || return
  codesign --verify --deep --strict "$app" >/dev/null 2>&1 ||
    dmg_error "app has an invalid nested signature: $app"
}

verify_bundle_versions() {
  local version="$1"
  local app="$2"
  local app_version
  local extension_version

  app_version="$(
    /usr/libexec/PlistBuddy \
      -c 'Print :CFBundleShortVersionString' \
      "$app/Contents/Info.plist"
  )" || dmg_error "app bundle version is missing" || return
  extension_version="$(
    /usr/libexec/PlistBuddy \
      -c 'Print :CFBundleShortVersionString' \
      "$app/Contents/PlugIns/ClamshellControl.appex/Contents/Info.plist"
  )" || dmg_error "control extension version is missing" || return

  [[ "$app_version" == "$version" ]] ||
    dmg_error "app bundle version must be $version: $app_version" || return
  [[ "$extension_version" == "$version" ]] ||
    dmg_error "control extension version must be $version: $extension_version"
}

resolve_release_dmg_path() {
  local version="$1"
  local output_directory="$2"

  validate_release_version "$version" || return
  mkdir -p "$output_directory"
  [[ -d "$output_directory" && ! -L "$output_directory" ]] ||
    dmg_error "output directory must be a real directory: $output_directory" || return

  local physical_output_directory
  physical_output_directory="$(cd "$output_directory" && pwd -P)"
  local dmg="$physical_output_directory/clamshellctl-v$version.dmg"
  local checksum="$dmg.sha256"

  [[ ! -L "$dmg" && ! -L "$checksum" ]] ||
    dmg_error "output path must stay inside the output directory" || return
  printf '%s\n' "$dmg"
}

verify_dmg_contents() {
  local dmg="$1"
  local mount_point
  mount_point="$(mktemp -d "${TMPDIR:-/tmp}/clamshellctl-dmg-mount.XXXXXX")" ||
    dmg_error "could not create DMG verification directory" || return

  if ! hdiutil attach \
    -readonly \
    -nobrowse \
    -mountpoint "$mount_point" \
    "$dmg" >/dev/null 2>&1; then
    rmdir "$mount_point"
    dmg_error "could not mount DMG for verification: $dmg"
    return
  fi

  local status=0
  [[ -d "$mount_point/Clamshell.app" ]] || status=1
  [[ -L "$mount_point/Applications" ]] || status=1
  [[ "$(readlink "$mount_point/Applications" 2>/dev/null || true)" == "/Applications" ]] ||
    status=1
  local entry_count
  entry_count="$(find "$mount_point" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')"
  [[ "$entry_count" == "2" ]] || status=1

  if ! hdiutil detach "$mount_point" >/dev/null 2>&1 &&
    ! hdiutil detach -force "$mount_point" >/dev/null 2>&1; then
    dmg_error "could not detach DMG after verification: $dmg"
    return
  fi
  rmdir "$mount_point" ||
    dmg_error "could not remove DMG verification directory: $mount_point" || return
  [[ "$status" == "0" ]] || dmg_error "DMG must contain only Clamshell.app and Applications"
}

create_release_dmg() {
  local version="$1"
  local output_directory="$2"
  local app="$3"

  local release_dmg
  release_dmg="$(resolve_release_dmg_path "$version" "$output_directory")" || return
  local release_checksum
  release_checksum="$release_dmg.sha256"
  verify_packaged_app "$app" || return
  verify_bundle_versions "$version" "$app" || return

  local staging_directory
  staging_directory="$(mktemp -d "${TMPDIR:-/tmp}/clamshellctl-dmg-stage.XXXXXX")" ||
    dmg_error "could not create DMG staging directory" || return
  if ! ditto "$app" "$staging_directory/Clamshell.app"; then
    rm -rf "$staging_directory"
    dmg_error "could not stage app bundle"
    return
  fi
  if ! ln -s /Applications "$staging_directory/Applications"; then
    rm -rf "$staging_directory"
    dmg_error "could not stage Applications symlink"
    return
  fi

  local temporary_dmg
  temporary_dmg="$(dirname "$release_dmg")/.clamshellctl-v$version.partial.dmg"
  if ! hdiutil create \
    -quiet \
    -volname "Clamshell" \
    -srcfolder "$staging_directory" \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$temporary_dmg"; then
    rm -rf "$staging_directory" "$temporary_dmg"
    dmg_error "could not create release DMG"
    return
  fi
  rm -rf "$staging_directory"

  if ! mv "$temporary_dmg" "$release_dmg"; then
    rm -f "$temporary_dmg"
    dmg_error "could not move release DMG into the output directory"
    return
  fi
  if ! hdiutil verify "$release_dmg" >/dev/null; then
    rm -f "$release_dmg"
    dmg_error "release DMG checksum is invalid: $release_dmg"
    return
  fi
  if ! verify_dmg_contents "$release_dmg"; then
    rm -f "$release_dmg"
    return
  fi

  if ! (
    cd "$(dirname "$release_dmg")" || exit
    shasum -a 256 "$(basename "$release_dmg")" >"$(basename "$release_checksum")"
    shasum -a 256 -c "$(basename "$release_checksum")" >/dev/null
  ); then
    rm -f "$release_checksum"
    dmg_error "could not write release checksum: $release_checksum"
    return
  fi
}
