#!/bin/bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly repository_root
# shellcheck disable=SC1091
source "$repository_root/scripts/lib/version-consistency.sh"

check_version_consistency "$repository_root"
