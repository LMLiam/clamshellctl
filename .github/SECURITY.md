# Security policy

## Supported versions

The maintainer provides security fixes only for the latest published release.
Update to the latest release before you report a problem that is fixed there.

## Report a vulnerability

Use [GitHub private vulnerability reporting](https://github.com/LMLiam/clamshellctl/security/advisories/new).
Do not open a public issue for a suspected vulnerability.

Include the affected version, macOS version, impact, reproduction steps, and a
minimal proof when safe. Do not include live credentials, secrets, personal
data, or destructive commands. We will acknowledge a report within seven days
and keep you informed while we validate and fix it.

## Security-sensitive surfaces

Changes to the root-owned helper, sudoers policy, installation paths, ownership
or permissions, process execution, Control Centre request boundary, release
workflow, checksum, and unsigned app distribution require extra review. The
helper must continue to accept only the exact `enable` and `disable` actions.
The sudoers policy must not grant password-free access to the public CLI,
`pmset`, a shell, or a user-writable executable.

The companion app and DMG use ad-hoc signing without Apple notarisation.
Release documentation must state that boundary and provide the specific
Gatekeeper approval steps without implying Apple review.

Read the [privilege model](../docs/privilege-model.md) for the intended paths,
permissions, commands, and Battery Power boundary.
