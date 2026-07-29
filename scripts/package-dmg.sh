#!/bin/bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly repository_root
# shellcheck disable=SC1091
source "$repository_root/scripts/lib/dmg-packaging.sh"

if [[ "$#" != "2" ]]; then
  echo "usage: scripts/package-dmg.sh VERSION OUTPUT_DIRECTORY" >&2
  exit 64
fi

version="$1"
output_directory="$2"
validate_release_version "$version"

for command in codesign ditto hdiutil lipo shasum swift xcodebuild xcodegen; do
  command -v "$command" >/dev/null || {
    echo "error: required command is unavailable: $command" >&2
    exit 1
  }
done

build_root="$repository_root/.build/package-dmg"
swift_build_path="$build_root/swift"
derived_data_path="$build_root/DerivedData"
assembled_app="$build_root/Clamshell.app"
mkdir -p "$build_root"

swift build \
  --package-path "$repository_root" \
  --scratch-path "$swift_build_path" \
  --configuration release \
  --arch arm64 \
  --arch x86_64 \
  --product clamshellctl
swift build \
  --package-path "$repository_root" \
  --scratch-path "$swift_build_path" \
  --configuration release \
  --arch arm64 \
  --arch x86_64 \
  --product clamshellctl-helper

swift_bin_path="$(
  swift build \
    --package-path "$repository_root" \
    --scratch-path "$swift_build_path" \
    --configuration release \
    --arch arm64 \
    --arch x86_64 \
    --show-bin-path
)"

(
  cd "$repository_root"
  xcodegen generate
  xcodebuild \
    -project Clamshell.xcodeproj \
    -scheme ClamshellApp \
    -configuration Release \
    -derivedDataPath "$derived_data_path" \
    ARCHS="arm64 x86_64" \
    ONLY_ACTIVE_ARCH=NO \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY=- \
    DEVELOPMENT_TEAM= \
    MARKETING_VERSION="$version" \
    build
)

rm -rf "$assembled_app"
ditto "$derived_data_path/Build/Products/Release/Clamshell.app" "$assembled_app"
bash "$repository_root/scripts/embed-command-products.sh" \
  "$assembled_app" \
  "$swift_bin_path/clamshellctl" \
  "$swift_bin_path/clamshellctl-helper"
create_release_dmg "$version" "$output_directory" "$assembled_app"

echo "Created $output_directory/clamshellctl-v$version.dmg"
echo "Created $output_directory/clamshellctl-v$version.dmg.sha256"
