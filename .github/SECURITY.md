# Security policy

## Supported versions

Only the latest published release receives security fixes. The project has not
published its first release yet.

## Report a vulnerability

Use [GitHub private vulnerability reporting](https://github.com/LMLiam/clamshellctl/security/advisories/new).
Do not open a public issue for a suspected vulnerability.

Include the affected version, macOS version, impact, reproduction steps, and a
minimal proof when safe. Do not include live credentials, secrets, personal
data, or destructive commands. We will acknowledge a report within seven days
and keep you informed while we validate and fix it.

## Security-sensitive surfaces

Changes to the root-owned helper, sudoers policy, installation paths, ownership
or permissions, process execution, and unsigned app distribution require extra
review. The helper must continue to accept only the exact `enable` and
`disable` actions. The sudoers policy must not grant password-free access to
the public CLI, `pmset`, a shell, or a user-writable executable.

The planned companion app and DMG will use ad-hoc signing without Apple
notarisation. Release documentation must state that boundary and provide the
specific Gatekeeper approval steps without implying Apple review.
