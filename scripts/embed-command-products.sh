#!/bin/bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly repository_root
# shellcheck disable=SC1091
source "$repository_root/scripts/lib/dmg-packaging.sh"

if [[ "$#" != "3" ]]; then
  echo "usage: scripts/embed-command-products.sh APP CLI HELPER" >&2
  exit 64
fi

app="$1"
cli="$2"
helper="$3"

verify_app_layout "$app"
verify_universal_executable "CLI payload" "$cli"
verify_universal_executable "helper payload" "$helper"

ditto "$cli" "$app/Contents/MacOS/clamshellctl"
ditto "$helper" "$app/Contents/Resources/clamshellctl-helper"
sign_app_bundle "$app"
verify_packaged_app "$app"
