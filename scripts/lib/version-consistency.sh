#!/bin/bash

version_consistency_error() {
  echo "error: $*" >&2
  return 1
}

require_version_file() {
  local description="$1"
  local path="$2"

  [[ -f "$path" && ! -L "$path" ]] ||
    version_consistency_error "$description is not a regular file: $path"
}

read_single_match() {
  local description="$1"
  local expression="$2"
  local path="$3"
  local matches

  matches="$(sed -nE "$expression" "$path")" ||
    version_consistency_error "could not read $description: $path" || return
  [[ -n "$matches" && "$(printf '%s\n' "$matches" | wc -l | tr -d ' ')" == "1" ]] ||
    version_consistency_error "$description must have one version value: $path" || return
  printf '%s\n' "$matches"
}

read_version_file() {
  local path="$1"
  local line_count

  line_count="$(awk 'END { print NR }' "$path")" ||
    version_consistency_error "could not read version.txt" || return
  [[ "$line_count" == "1" ]] ||
    version_consistency_error "version.txt must contain one line" || return
  tr -d '\n' <"$path"
}

read_cli_version() {
  read_single_match \
    "CLI version" \
    's/^[[:space:]]*public static let current = "([^"]+)"[[:space:]]*$/\1/p' \
    "$1"
}

read_app_version() {
  read_single_match \
    "app version" \
    's/^[[:space:]]*MARKETING_VERSION:[[:space:]]*"([^"]+)"([[:space:]]*#.*)?$/\1/p' \
    "$1"
}

read_plist_version_reference() {
  read_single_match \
    "$1 version" \
    '/<key>CFBundleShortVersionString<\/key>/{n;s/^[[:space:]]*<string>([^<]+)<\/string>[[:space:]]*$/\1/p;}' \
    "$2"
}

read_manifest_version() {
  jq -er '.["."] | strings' "$1" 2>/dev/null ||
    version_consistency_error "release manifest must contain one string version"
}

require_release_updater() {
  local configuration="$1"
  local path="$2"

  jq -e \
    --arg path "$path" \
    '.packages["."]."extra-files"
      | map(if type == "string" then . else .path end)
      | index($path) != null' \
    "$configuration" >/dev/null 2>&1 ||
    version_consistency_error "release configuration must update $path"
}

verify_release_configuration() {
  local configuration="$1"

  jq -e '.packages["."]."release-type" == "simple"' \
    "$configuration" >/dev/null 2>&1 ||
    version_consistency_error "release configuration must use the simple release type" ||
    return
  require_release_updater \
    "$configuration" \
    "Sources/ClamshellCore/BuildVersion.swift" || return
  require_release_updater "$configuration" "project.yml"
}

require_version_match() {
  local description="$1"
  local expected="$2"
  local actual="$3"

  [[ "$actual" == "$expected" ]] ||
    version_consistency_error "$description must be $expected: $actual"
}

require_version_reference() {
  local description="$1"
  local expected="$2"
  local actual="$3"

  [[ "$actual" == "$expected" ]] ||
    version_consistency_error "$description must use $expected: $actual"
}

check_version_consistency() {
  local root="$1"
  local version_path="$root/version.txt"
  local cli_path="$root/Sources/ClamshellCore/BuildVersion.swift"
  local project_path="$root/project.yml"
  local manifest_path="$root/.release-please-manifest.json"
  local configuration_path="$root/release-please-config.json"
  local app_plist_path="$root/App/ClamshellApp/Info.plist"
  local control_plist_path="$root/App/ClamshellControl/Info.plist"

  command -v jq >/dev/null ||
    version_consistency_error "jq is required" || return

  local path
  for path in \
    "$version_path" \
    "$cli_path" \
    "$project_path" \
    "$manifest_path" \
    "$configuration_path" \
    "$app_plist_path" \
    "$control_plist_path"; do
    require_version_file "version source" "$path" || return
  done

  local version
  version="$(read_version_file "$version_path")" || return
  [[ "$version" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] ||
    version_consistency_error \
      "version.txt must use MAJOR.MINOR.PATCH without leading zeros: $version" ||
    return

  local cli_version
  cli_version="$(read_cli_version "$cli_path")" || return
  require_version_match "CLI version" "$version" "$cli_version" || return

  local app_version
  app_version="$(read_app_version "$project_path")" || return
  require_version_match "app version" "$version" "$app_version" || return

  local manifest_version
  manifest_version="$(read_manifest_version "$manifest_path")" || return
  require_version_match \
    "release manifest version" \
    "$version" \
    "$manifest_version" || return

  local app_reference
  app_reference="$(read_plist_version_reference "app bundle" "$app_plist_path")" ||
    return
  require_version_reference \
    "app bundle version" \
    "\$(MARKETING_VERSION)" \
    "$app_reference" || return

  local control_reference
  control_reference="$(
    read_plist_version_reference "control extension" "$control_plist_path"
  )" || return
  require_version_reference \
    "control extension version" \
    "\$(MARKETING_VERSION)" \
    "$control_reference" || return

  grep -Fq "x-release-please-version" "$cli_path" ||
    version_consistency_error "CLI version needs a release-please marker" ||
    return
  grep -Fq "x-release-please-version" "$project_path" ||
    version_consistency_error "app version needs a release-please marker" ||
    return
  verify_release_configuration "$configuration_path" || return

  printf 'Version consistency checks passed: %s\n' "$version"
}
