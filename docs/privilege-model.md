# Privilege model

Routine state changes need root access because macOS restricts `pmset` changes.
`clamshellctl` uses a small helper and an exact sudoers allow-list for these
changes.

## Setup boundary

The Homebrew command uses this explicit setup step:

```bash
sudo clamshellctl setup
```

The companion app shows one macOS administrator prompt for the same operation.
Setup does these actions:

1. Copy the helper payload to its managed path.
2. Set the helper owner to `root:wheel` and its mode to `0755`.
3. Create a sudoers policy for the user who started `sudo`.
4. Set the policy owner to `root:wheel` and its mode to `0440`.
5. Validate the staged policy with `visudo`.
6. Replace the managed policy and helper.
7. Verify the files and both permitted commands.

Repeated setup does not replace valid files.

## Managed privileged paths

| Path | Purpose | Owner and mode |
| --- | --- | --- |
| `/Library/PrivilegedHelperTools/clamshellctl-helper` | Runs one state change | `root:wheel`, `0755` |
| `/etc/sudoers.d/clamshellctl` | Allows two helper commands | `root:wheel`, `0440` |

The optional app command link is `/usr/local/bin/clamshellctl`. Setup does not
replace an existing file or a link to another command.

## Runtime boundary

The sudoers policy allows only these command forms for the setup user:

```text
/Library/PrivilegedHelperTools/clamshellctl-helper enable
/Library/PrivilegedHelperTools/clamshellctl-helper disable
```

The helper rejects all other arguments. It maps the accepted actions to these
system changes:

```text
/usr/bin/pmset -b disablesleep 1
/usr/bin/pmset -b disablesleep 0
```

The `-b` option limits the change to Battery Power. The helper does not change
the AC Power setting.

The policy does not allow password-free access to:

- `clamshellctl`
- `Clamshell.app`
- a shell
- general `pmset` commands
- another executable or argument

The public command uses `sudo -n` for a permitted helper action. It does not
show an administrator prompt during a routine state change. If setup is not
valid, the command stops and tells you to run setup.

## DMG trust boundary

The release DMG and nested app files use ad-hoc signatures. The packaging
process verifies these signatures, but Apple does not identify the developer
or notarise the app. Verify the SHA-256 file before you approve the app in
Privacy & Security.

The planned Homebrew formula will build the command and helper from the tagged
source. It will not install privileged files during `brew install`.
