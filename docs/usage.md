# Usage

Run `clamshellctl` without a subcommand to show the current state.

## Read the state

```bash
clamshellctl status
```

The command reports `enabled` or `disabled`. It also reports the end time for
temporary enablement.

## Change the state

```bash
clamshellctl enable
clamshellctl disable
clamshellctl toggle
```

`enable` allows clamshell mode while the Mac uses battery power. `disable`
prevents it. `toggle` changes the current state.

The command reads the system state after a change. It reports success only if
the requested state is active.

Use `--quiet` with a state change, setup, or removal command to suppress
successful output. Errors still use standard error. The `status` command does
not accept `--quiet` because its purpose is to print the state.

## Use temporary enablement

Add `--for` and a whole number of minutes, hours, or days:

```bash
clamshellctl enable --for 30m
clamshellctl enable --for 2h
clamshellctl enable --for 1d
```

The maximum duration is 30 days. The command records an absolute deadline and
uses a user LaunchAgent to disable the mode. Sleep does not restart the
duration.

A new temporary enablement replaces the current timer. `enable` without
`--for` and `disable` remove the current timer.

## Use Control Centre

The Control Centre control requires macOS 26 or later and the DMG installation.

1. Open Control Centre and select **Edit Controls**.
2. Add **Battery Clamshell Mode**.
3. Select the control to enable or disable the mode.

The filled state means that battery clamshell mode is enabled. The clear state
means that it is disabled. The control reads the system state again after each
request.

The companion app runs in the background for control requests. It has no Dock
icon. If you open Clamshell from Spotlight, the existing app instance shows the
setup window.

## Remove clamshellctl

Disable the mode before removal. This action also removes an active timer.

### Homebrew installation

```bash
clamshellctl disable
sudo clamshellctl uninstall
brew uninstall clamshellctl
```

### DMG installation

Run these commands while the app is still in `/Applications`:

```bash
/Applications/Clamshell.app/Contents/MacOS/clamshellctl disable
sudo /Applications/Clamshell.app/Contents/MacOS/clamshellctl uninstall --remove-command
```

Then move `Clamshell.app` to the Bin. The removal command deletes only the
managed helper, sudoers policy, and app-owned terminal link. It does not delete
an unrelated item at `/usr/local/bin/clamshellctl`.
