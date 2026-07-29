<p align="center">
  <img src="docs/assets/clamshellctl.png" width="720" alt="A closed Mac notebook connected to an active external display">
</p>

# clamshellctl

[![CI](https://github.com/LMLiam/clamshellctl/actions/workflows/ci.yml/badge.svg)](https://github.com/LMLiam/clamshellctl/actions/workflows/ci.yml)
[![CodeQL](https://github.com/LMLiam/clamshellctl/actions/workflows/codeql.yml/badge.svg)](https://github.com/LMLiam/clamshellctl/actions/workflows/codeql.yml)

Control battery clamshell mode on macOS.

`clamshellctl` lets a Mac notebook use an external display while the notebook
is closed and on battery power. You can use a terminal command on macOS 13 or
later. On macOS 26 or later, you can also use a Control Centre control.

> [!IMPORTANT]
> The first public release is not available. Do not use an asset from an
> untrusted source. You can build the project from source while release work
> continues.

## Features

- Read, enable, disable, or toggle battery clamshell mode.
- Enable the mode for up to 30 days.
- Use a stateful Control Centre control on macOS 26 or later.
- Install one restricted helper for password-free routine changes.
- Keep the AC Power setting unchanged.

## Install

The project will provide two installation methods:

- **Homebrew:** Installs the terminal command and helper payload on macOS 13 or
  later.
- **DMG:** Installs a self-contained app, Control Centre extension, terminal
  command, and helper payload on macOS 26 or later.

Read the [installation guide](docs/installation.md) for the requirements,
checksum check, Gatekeeper approval, and setup steps.

## Use the command

Run setup once after installation:

```bash
sudo clamshellctl setup
```

Then use the command without a password:

```bash
clamshellctl status
clamshellctl enable
clamshellctl enable --for 2h
clamshellctl disable
clamshellctl toggle
```

Read the [usage guide](docs/usage.md) for timers, Control Centre, and removal.

## Safety

The restricted helper accepts only `enable` and `disable`. It changes only the
Battery Power `disablesleep` setting. The sudoers policy does not give
password-free access to the public command, the app, a shell, or other
`pmset` arguments.

Read the [privilege model](docs/privilege-model.md) for the installed paths,
file permissions, and command boundary.

## Help

- Use the [troubleshooting guide](docs/troubleshooting.md) for common problems.
- Read [SUPPORT.md](SUPPORT.md) before you ask a usage question.
- Report a security problem through the process in [SECURITY.md](SECURITY.md).

## Contribute

Read [CONTRIBUTING.md](CONTRIBUTING.md) for the development requirements,
checks, style rules, and pull request process.

## Licence

`clamshellctl` is available under the [MIT Licence](LICENSE).
