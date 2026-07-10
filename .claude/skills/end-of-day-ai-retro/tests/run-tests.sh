#!/usr/bin/env bash
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$TESTS_DIR/../scripts" && pwd)"
FIXTURES_DIR="$TESTS_DIR/fixtures"
failed=0

pass() {
  echo "PASS: $1"
}

fail() {
  echo "FAIL: $1"
  failed=$((failed + 1))
}

temp_home="$(mktemp -d)"
trap 'rm -rf "$temp_home"' EXIT

if HOME="$temp_home" "$SCRIPTS_DIR/session-files.sh" retro >/dev/null; then
  pass "session-files.sh retro succeeds without session directories"
else
  fail "session-files.sh retro succeeds without session directories"
fi

if HOME="$temp_home" "$SCRIPTS_DIR/generate-report.sh" --dry-run | grep -q '日次振り返りレポート'; then
  pass "generate-report.sh --dry-run produces a report"
else
  fail "generate-report.sh --dry-run produces a report"
fi

if "$SCRIPTS_DIR/sanitize-check.sh" "$FIXTURES_DIR/sensitive.jsonl" >/dev/null 2>&1; then
  fail "sanitize-check.sh rejects sensitive fixture"
else
  pass "sanitize-check.sh rejects sensitive fixture"
fi

if "$SCRIPTS_DIR/sanitize-check.sh" "$FIXTURES_DIR/success-session.jsonl" >/dev/null; then
  pass "sanitize-check.sh accepts safe fixture"
else
  fail "sanitize-check.sh accepts safe fixture"
fi

mkdir -p "$temp_home/.codex/sessions/fake"
cp "$FIXTURES_DIR/broken.jsonl" "$temp_home/.codex/sessions/fake/broken.jsonl"
if HOME="$temp_home" "$SCRIPTS_DIR/session-files.sh" retro >/dev/null; then
  pass "session-files.sh retro tolerates broken JSONL"
else
  fail "session-files.sh retro tolerates broken JSONL"
fi

if [ "$failed" -eq 0 ]; then
  echo "All tests passed"
else
  echo "$failed tests failed"
fi

exit "$failed"
