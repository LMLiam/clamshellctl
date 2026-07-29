# Installation

The first public release is not available. The commands in this guide will
work after the project publishes the release assets and Homebrew formula.

## Choose an installation method

| Method | macOS | Includes Control Centre | Includes terminal command |
| --- | --- | --- | --- |
| Homebrew | 13 or later | No | Yes |
| DMG | 26 or later | Yes | Optional link |

Both methods include the restricted helper payload. Installation does not add
privileged files. You approve privileged setup in a separate step.

## Install with Homebrew

You need macOS 13 or later and a current Homebrew installation.

1. Install the formula from the project tap:

   ```bash
   brew install LMLiam/tap/clamshellctl
   ```

2. Install the restricted helper and sudoers policy:

   ```bash
   sudo clamshellctl setup
   ```

3. Check the installation:

   ```bash
   clamshellctl --version
   clamshellctl status
   ```

The formula does not install privileged files during `brew install`. The
`setup` command is the only installation step that needs administrator access.

Homebrew documents how a direct install from a
[third-party tap](https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap#installing)
limits trust to the selected formula.

## Install the companion app from a DMG

You need macOS 26 or later. The app and all command payloads contain `arm64`
and `x86_64` code.

### Verify the download

Download the DMG and its `.sha256` file from the same GitHub release. Replace
`X.Y.Z` in this command with the release version:

```bash
cd ~/Downloads
shasum -a 256 -c clamshellctl-vX.Y.Z.dmg.sha256
```

Continue only if the command reports `OK`.

### Copy and approve the app

1. Open the DMG.
2. Drag `Clamshell.app` to the Applications link.
3. Eject the DMG.
4. Open Clamshell from the Applications folder or Spotlight.

The app has an ad-hoc signature and is not notarised. macOS blocks its first
launch. This warning is expected, but it means that Apple did not verify the
developer or scan this build during notarisation.

If you trust the GitHub release and its checksum:

1. Try to open Clamshell once.
2. Open **System Settings** and select **Privacy & Security**.
3. Go to **Security** and select **Open Anyway**.
4. Confirm that you want to open Clamshell.

Apple explains this process and its risks in
[Open a Mac app from an unknown developer](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac).

### Complete setup

1. Select **Set Up** in the Clamshell window.
2. Approve the administrator prompt.
3. Open Control Centre and select **Edit Controls**.
4. Add **Battery Clamshell Mode**.

Enable **Install the Terminal command** before setup if you also want
`/usr/local/bin/clamshellctl`. You can select **Install Terminal Command**
after setup if you did not enable it at first.

## Update

For Homebrew, run:

```bash
brew update
brew upgrade clamshellctl
```

For the DMG, download and verify the new release. Replace the app in
`/Applications`, then open it. Select **Set Up** if the app reports that the
helper needs repair. This step replaces an old helper with the app payload.

## Remove

Follow the [removal steps](usage.md#remove-clamshellctl). Disable battery
clamshell mode before you remove the helper or app.
