# CodeRabbit Configuration Implementation Plan

**Goal:** Add a version-controlled CodeRabbit policy that produces strict,
high-signal reviews without spending review allowance on drafts or incremental
pushes.

**Architecture:** `.coderabbit.yaml` owns review timing, presentation,
pre-merge checks, tool configuration, and path-specific guidance. The existing
repository-quality design records the policy, while CodeRabbit's manual
pre-merge command verifies the effective configuration on pull request #11.

**Tech stack:** CodeRabbit schema v2, YAML, SwiftLint, ShellCheck, GitHub pull
requests.

---

### Task 1: Add the repository configuration

**Files:**

- Create: `.coderabbit.yaml`

- [ ] **Step 1: Replace the minimal configuration**

Use this complete configuration:

```yaml
# yaml-language-server: $schema=https://coderabbit.ai/integrations/schema.v2.json
language: "en-GB"
early_access: false

reviews:
  profile: "assertive"
  request_changes_workflow: true
  high_level_summary: true
  high_level_summary_in_walkthrough: true
  high_level_summary_instructions: >-
    Summarise user-visible behaviour, security boundaries, and verification in
    concise British English. Omit release-note filler.
  review_status: true
  review_details: false
  commit_status: true
  fail_commit_status: false
  collapse_walkthrough: true
  changed_files_summary: true
  sequence_diagrams: false
  estimate_code_review_effort: false
  assess_linked_issues: true
  related_issues: false
  related_prs: false
  suggested_labels: false
  auto_apply_labels: false
  suggested_reviewers: false
  in_progress_fortune: false
  poem: false
  enable_prompt_for_ai_agents: false
  abort_on_close: true

  auto_review:
    enabled: true
    auto_incremental_review: false
    drafts: false

  finishing_touches:
    docstrings:
      enabled: false

  pre_merge_checks:
    docstrings:
      mode: "off"
    title:
      mode: "off"
    description:
      mode: "warning"
    issue_assessment:
      mode: "warning"

  path_instructions:
    - path: "**/*"
      instructions: |
        Report only findings with a concrete correctness, security, or
        maintainability consequence. State the consequence and the smallest
        suitable remedy. Do not request cosmetic churn, redundant comments,
        or documentation for self-explanatory implementation details. Verify
        each finding against the current code and repository conventions.
    - path: "**/*.swift"
      instructions: |
        Follow the Google Swift Style Guide and the repository SwiftLint
        policy. Prefer idiomatic Swift 6, narrow access control, Sendable-safe
        concurrency, typed errors, and explicit failure handling. Treat one
        primary responsibility per file as a design goal, not a rigid
        one-declaration rule.
    - path: "Sources/ClamshellCore/Privilege/**/*.swift"
      instructions: |
        Treat helper actions, sudoers generation, filesystem replacement,
        ownership, permissions, username handling, and process construction as
        security boundaries. Check exact allow-lists and failure consistency.
    - path: "Sources/ClamshellHelper/**/*.swift"
      instructions: |
        Treat every accepted argument and privileged command as part of the
        root boundary. Reject broader command shapes and require observable
        verification of requested state changes.
    - path: "Tests/**/*.swift"
      instructions: |
        Review observable behaviour, failure paths, and privilege constraints.
        Tests must not mutate live power settings or privileged system files.
        Do not request assertions about private implementation or call order
        unless order is part of the contract.
    - path: ".github/workflows/**"
      instructions: |
        Check immutable action pinning, least-privilege permissions, untrusted
        pull-request code execution, concurrency, timeouts, and fail-closed
        status handling. Request comments only for non-obvious security
        constraints or necessary tool suppressions.
    - path: "scripts/**"
      instructions: |
        Check quoting, exit-status preservation, temporary-file cleanup, and
        fail-closed behaviour. Prefer portable shell accepted by ShellCheck.
    - path: "**/*.md"
      instructions: |
        Check technical accuracy against current behaviour. Use concise British
        English. Reject stale paths, unsupported claims, and internal AI
        process metadata.

  tools:
    swiftlint:
      enabled: true
      config_file: ".swiftlint.yml"
    shellcheck:
      enabled: true

chat:
  auto_reply: true
```

- [ ] **Step 2: Parse the YAML locally**

Run:

```bash
ruby -ryaml -e '
  config = YAML.safe_load(File.read(".coderabbit.yaml"), aliases: false)
  abort "invalid CodeRabbit config" unless
    config.dig("reviews", "profile") == "assertive" &&
      config.dig("reviews", "auto_review", "drafts") == false &&
      config.dig("reviews", "auto_review", "auto_incremental_review") == false &&
      config.dig("reviews", "pre_merge_checks", "docstrings", "mode") == "off"
'
```

Expected: exit status 0 with no output.

- [ ] **Step 3: Check formatting and the repository diff**

Run:

```bash
git diff --check
scripts/check.sh
```

Expected: no whitespace errors; formatting, SwiftLint, tests, builds, and
workflow lint all pass.

### Task 2: Publish and verify the effective policy

**Files:**

- Add: `.coderabbit.yaml`
- Verify: pull request #11 metadata and CodeRabbit walkthrough

- [ ] **Step 1: Commit the configuration**

Run:

```bash
git add .coderabbit.yaml
git commit -m "ci(review): configure high-signal CodeRabbit reviews"
git push
```

Expected: only `.coderabbit.yaml` is included in the commit.

- [ ] **Step 2: Verify pull-request issue coverage**

Confirm that pull request #11 states that it partially addresses issues #7 and
#8 without closing either issue.

- [ ] **Step 3: Run the configured pre-merge checks**

Post this pull-request comment:

```text
@coderabbitai run pre-merge checks
```

Expected: the docstring and title checks are disabled. Description and linked
issue assessment run as warnings, with the issue assessment recognising #7 and
#8 as partial scope.

- [ ] **Step 4: Verify the final review state**

Run:

```bash
gh pr checks 11 --repo LMLiam/clamshellctl
git status --short --branch
```

Expected: required checks pass or remain in progress with no configuration
failure; no CodeRabbit-authored review thread remains unresolved; `.vscode/`
remains untouched.
