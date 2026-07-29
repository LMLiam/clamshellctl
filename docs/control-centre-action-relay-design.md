# Control Centre action relay design

Status: Approved

Date: 29 July 2026

## Goal

Let the Control Centre toggle change battery clamshell mode in an ad-hoc-signed
Clamshell app. The action must not show a window, a Dock icon, or a menu-bar
item.

## Constraints

- The GitHub release must not require an Apple Developer Program membership.
- The app and its extension must support ad-hoc signing.
- The sandboxed extension must not run `sudo`, `pmset`, or the privileged helper.
- The control must show the value that `pmset` reports.
- The action must accept only the enabled and disabled states.
- The existing CLI and privileged helper must remain the authority for changes.

## Decision

The control extension will send a fixed request to the containing app. The app
will process the request in the background and use the existing privileged
helper.

The request will use a private URL with one of these forms:

```text
clamshellctl://battery-clamshell/enable
clamshellctl://battery-clamshell/disable
```

The app will register the `clamshellctl` URL scheme. It will reject URLs that
have a different scheme, host, path, query, or fragment.

## Action flow

1. The control value provider reads the current `pmset` state.
2. The user changes the Control Centre toggle.
3. The extension opens the URL for the requested state without app activation.
4. macOS starts Clamshell or sends the URL to the running app.
5. Clamshell validates the URL and maps it to an enabled or disabled value.
6. Clamshell calls the existing privileged helper through `ClamshellService`.
7. The service verifies the value that `pmset` reports.
8. Clamshell asks Control Centre to reload the control.
9. The value provider reads the verified state and updates the control colour.

The extension will not store an optimistic value. The control colour will show
the system value after each reload.

## App launch behaviour

Clamshell will keep its `LSUIElement` configuration. The setup scene will use a
suppressed default launch behaviour, so a control request does not create a
window.

A normal user launch will continue to open the setup window. A control request
will start or wake the app in the background and will not activate it.

The URL handler must support both a cold app launch and a running app.

## Component responsibilities

### Control extension

- Read the current state.
- Create one fixed action URL.
- Ask macOS to open the URL without activation.
- Report an error if macOS cannot deliver the URL.

### Action URL parser

- Parse the URL without shell evaluation.
- Accept only the two documented URLs.
- Return a typed enabled or disabled value.
- Reject all extra input.

### Background action handler

- Receive a typed value from the parser.
- Use the existing service and helper interfaces.
- Reload the control after success or failure.
- Write failures to the unified system log without sensitive data.

### Control value provider

- Read the real power-management value.
- Use the same state interpretation as the CLI.
- Do not depend on the action URL or a cached toggle value.

## Security

The URL is a local command interface, so another local process can open it. The
handler must expose no arbitrary command, executable path, environment value,
or shell argument. It must map the two accepted paths to the two operations that
the installed helper already permits.

The app must not run URL text through a shell. It must not add a general command
execution interface to the helper.

An invalid request must have no effect. A missing or invalid privileged setup
must also have no effect.

## Error handling

- If the extension cannot open the URL, the intent will report failure.
- If validation fails, the app will ignore the request and record the reason.
- If the helper fails, the app will record the failure and reload the control.
- If verification fails, the control will continue to show the value that the
  provider reads.
- A control action will not open the setup window. The user can open Clamshell
  to repair an invalid setup.

## Verification

Automated tests will cover:

- Both accepted action URLs.
- Invalid schemes, hosts, paths, queries, and fragments.
- Mapping from each accepted URL to one typed state.
- Successful helper execution and control reload.
- Helper and verification failures.
- No execution after URL validation fails.
- The independent control value provider.

The manual feasibility test will cover:

- Enable and disable actions from Control Centre.
- Correct control colour after each action.
- A cold background launch with no visible window.
- A warm background wake with no visible window.
- No Dock icon or menu-bar item.
- State changes made through the CLI.
- Behaviour after the user approves the ad-hoc-signed app in macOS.

## Distribution

The release disk image will contain the ad-hoc-signed app, CLI, and helper. The
installation guide will tell the user how to approve the app in Privacy &
Security. The release will not require notarisation, a Developer ID certificate,
or a paid Apple Developer Program membership.

## Fallback

The feasibility test must confirm that the control extension can open the
containing app without activation. If macOS blocks that operation, use a narrow
local XPC relay with the same typed request and helper boundaries.

Do not publish a control that changes only its displayed state.

## Out of scope

- An Apple Shortcut.
- A menu-bar item.
- Developer ID signing or notarisation.
- Arbitrary shell-script execution.
- Automatic behaviour based on connected USB-C devices.
