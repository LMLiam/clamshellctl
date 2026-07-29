# Control Centre feasibility test

Status: Pass

This test checks the ad-hoc-signed Control Centre companion before publication.
Do not publish the DMG until all manual checks pass.

## Test environment

- Date: 29 July 2026
- macOS: 27.0 (26A5353q)
- Xcode: 26.6 (17F113)
- Swift: 6.3.3
- Architecture: arm64
- Signing: ad hoc

## Automated checks

| Check | Result | Observation |
| --- | --- | --- |
| Package tests | Pass | All 71 tests passed. |
| Control extension tests | Pass | All 10 tests passed in the Release configuration. |
| Companion app tests | Pass | All 17 tests passed in the Release configuration. |
| Release app build | Pass | Xcode built the app and control extension with ad-hoc signing. |
| Nested signature | Pass | `codesign --verify --deep --strict` reported a valid app. |
| URL registration | Pass | The app registered the exact `clamshellctl` scheme. |
| Intent boundary | Pass | The extension contains the control intent. The main executable does not contain it. |
| Cold request | Pass | macOS started the app in the background and disabled battery clamshell mode. The active app did not change. |
| Warm request | Pass | The running app enabled battery clamshell mode in the background. The active app did not change. |
| Failure request | Pass | A request with no installed helper did not change the power state or show setup. |
| Control Centre request | Pass | The control applied disable and stayed inactive. The CLI and `pmset` reported the disabled state. |
| Disk image checksum | Pass | `hdiutil verify` reported a valid checksum. |
| Gatekeeper rejection | Pass | `spctl` rejected the unnotarised disk image as expected. |
| Quarantine marker | Pass | The local disk image has a test quarantine attribute. |

The test artefact is `.build/feasibility/Clamshell-feasibility.dmg`.
It is an arm64-only local artefact and is not a release artefact.
The installed action relay came from
`.build/feasibility/Clamshell-action-relay-v2.app`.

## Build commands

```bash
swift build -c release --product clamshellctl
swift build -c release --product clamshellctl-helper
xcodegen generate
xcodebuild -project Clamshell.xcodeproj -scheme ClamshellControlTests \
  -configuration Release -destination 'platform=macOS,arch=arm64' \
  CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= test
xcodebuild -project Clamshell.xcodeproj -scheme ClamshellApp \
  -configuration Release -destination 'platform=macOS,arch=arm64' \
  CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= build
codesign --verify --deep --strict --verbose=2 Clamshell.app
/usr/bin/open 'clamshellctl://battery-clamshell/disable'
/Applications/Clamshell.app/Contents/MacOS/clamshellctl status
/usr/bin/open 'clamshellctl://battery-clamshell/enable'
/Applications/Clamshell.app/Contents/MacOS/clamshellctl status
hdiutil verify .build/feasibility/Clamshell-feasibility.dmg
spctl --assess --type open --context context:primary-signature \
  .build/feasibility/Clamshell-feasibility.dmg
```

## Manual checks

Run these checks from a separate local test account.

- [ ] macOS shows the expected Gatekeeper warning.
- [ ] Privacy & Security permits the app after explicit approval.
- [x] macOS discovers Battery Clamshell Mode in Control Centre.
- [x] The control shows the inactive state when `SleepDisabled` is `0`.
- [x] One authorisation prompt completes setup.
- [x] The helper owner is `root:wheel` and its mode is `0755`.
- [x] The sudoers policy owner is `root:wheel` and its mode is `0440`.
- [x] Setup validates the sudoers policy with `visudo`.
- [x] The background relay enables battery clamshell mode.
- [x] The control shows the active state after enablement.
- [x] The control disables battery clamshell mode.
- [x] The control reloads from the real system state.
- [ ] Repeated setup does not change valid files.
- [ ] Repeated removal succeeds safely.
- [ ] Removal preserves an unrelated `/usr/local/bin/clamshellctl` item.
- [ ] A second ad-hoc-signed app build preserves control discovery and setup.

Record only the result and non-sensitive command output. Do not record account names or passwords.
