# Security policy

## Supported versions

The maintainer provides security fixes only for the latest published release.
Update to the latest release before you report a problem that is fixed there.

## Report a vulnerability

Do not open a public issue for a security problem. Use
[private vulnerability reporting](https://github.com/LMLiam/clamshellctl/security/advisories/new).

Include:

- the affected version and installation method
- the macOS version and Mac architecture
- concise reproduction steps
- the expected and actual security boundary
- a proof of concept when it is safe to share
- a proposed fix, if you have one

Remove passwords, tokens, private keys, account names, and unrelated personal
data. Do not test against another person's computer or data.

The maintainer will use the private report to confirm the problem, discuss a
fix, and plan coordinated disclosure. Do not publish the details before the
maintainer and reporter agree on disclosure.

## Important security boundaries

Security reports can include:

- helper argument validation
- sudoers policy expansion or bypass
- replacement of files outside the managed paths
- unsafe handling of root-owned files
- command or path injection
- Control Centre requests that bypass the helper boundary
- release asset, checksum, or workflow integrity

Read the [privilege model](docs/privilege-model.md) for the intended boundary.
General bugs and support questions belong in the public issue forms.
