#!/bin/bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly repository_root
readonly validator="$repository_root/scripts/check-conventional-subject.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_accepts() {
  local subject="$1"
  "$validator" "$subject" >/dev/null 2>&1 ||
    fail "expected subject to pass: $subject"
}

assert_rejects() {
  local subject="$1"
  if "$validator" "$subject" >/dev/null 2>&1; then
    fail "expected subject to fail: $subject"
  fi
}

run_tests() {
  [[ -x "$validator" ]] || fail "missing executable validator: $validator"

  local verb
  for verb in feat fix docs test build ci refactor perf style chore revert; do
    assert_accepts "$verb(test-area): describe the change"
  done

  assert_rejects "feat: omit the area"
  assert_rejects "feature(cli): use an unsupported verb"
  assert_rejects "feat(CLI): use an upper-case area"
  assert_rejects "feat(cli): end with a full stop."
  assert_rejects "feat(cli): "
  assert_rejects "feat(cli):"
  assert_rejects " feat(cli): start with whitespace"

  echo "All conventional subject tests passed."
}

run_tests
