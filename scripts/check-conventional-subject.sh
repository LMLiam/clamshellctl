#!/bin/bash
set -euo pipefail

readonly subject="${1:-}"
readonly verbs='feat|fix|docs|test|build|ci|refactor|perf|style|chore|revert'
readonly pattern="^(${verbs})\([a-z0-9][a-z0-9-]*\): .+"

if [[ ! "$subject" =~ $pattern ]]; then
  echo "Expected verb(area): description, received: $subject" >&2
  exit 1
fi
