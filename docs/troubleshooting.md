# Troubleshooting

Start with these commands when the terminal command is available:

```bash
clamshellctl --version
clamshellctl status
```

For a DMG installation without the optional terminal link, use:

```bash
/Applications/Clamshell.app/Contents/MacOS/clamshellctl status
```

## macOS blocks the app

The DMG is not notarised. Verify the downloaded checksum first. Then try to
open the app and use **Privacy & Security > Open Anyway**. Read the detailed
[Gatekeeper steps](installation.md#copy-and-approve-the-app).

## Battery Clamshell Mode is not in Control Centre

Check each requirement:

- The Mac uses macOS 26 or later.
- `Clamshell.app` is in `/Applications`.
- You opened the installed app at least once.
- The app contains `Contents/PlugIns/ClamshellControl.appex`.

Open Clamshell from Spotlight. Complete setup, then open Control Centre and
select **Edit Controls** again.

## The control returns to the clear state

The control shows the system state, not the last requested state. Run
`clamshellctl status`. If setup is missing or invalid, open Clamshell and select
**Set Up**. The app can replace an invalid helper.

If the state still does not change, include the safe error text in a bug report.
Do not include passwords, account names, or a complete environment dump.

## The app reports incomplete files

The app needs its bundled command, helper, and Control Centre extension.

If the window shows **Remove Privileged Setup**, select it first. Then remove
the incomplete app and install a complete copy in `/Applications`.

If the removal button is not available, install a complete app first. Open it
and remove or repair the privileged setup from the new copy.

## Setup reports a command link conflict

The app creates `/usr/local/bin/clamshellctl` only when that path is free or
already links to the installed app command. It does not replace another file.

Inspect the path before you change it:

```bash
ls -l /usr/local/bin/clamshellctl
```

Keep the existing command, or move it to a safe backup location. Then run setup
again.

## Status reports that a timer deadline passed

Run:

```bash
clamshellctl disable
```

This command disables battery clamshell mode and removes the stale timer files.

## An update reports that setup needs repair

The installed helper does not match the new payload. For Homebrew, run:

```bash
sudo clamshellctl setup
```

For the companion app, open Clamshell and select **Set Up**.

## Get more help

Read [SUPPORT.md](../SUPPORT.md) and use the correct issue form. Use private
vulnerability reporting for a security problem.
