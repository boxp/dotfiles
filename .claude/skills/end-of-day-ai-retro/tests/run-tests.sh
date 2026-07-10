#!/usr/bin/env bash
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$TESTS_DIR/../scripts" && pwd)"
FIXTURES_DIR="$TESTS_DIR/fixtures"
failed=0

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; failed=$((failed + 1)); }
assert() {
  local name="$1"; shift
  if "$@"; then pass "$name"; else fail "$name"; fi
}

temp_home="$(mktemp -d)"
trap 'rm -rf "$temp_home"' EXIT
mkdir -p "$temp_home/sessions/codex" "$temp_home/sessions/claude" "$temp_home/task-board/BOXP-TEST/20260710T120000Z"
cp "$FIXTURES_DIR/success-session.jsonl" "$temp_home/sessions/codex/success.jsonl"
cp "$FIXTURES_DIR/failed-session.jsonl" "$temp_home/sessions/codex/failed-1.jsonl"
cp "$FIXTURES_DIR/failed-session.jsonl" "$temp_home/sessions/claude/failed-2.jsonl"
cp "$FIXTURES_DIR/broken.jsonl" "$temp_home/sessions/claude/broken.jsonl"
cp "$FIXTURES_DIR/sensitive.jsonl" "$temp_home/sessions/codex/sensitive.jsonl"
find "$temp_home/sessions" -type f -exec touch -d '2026-07-10 12:00:00 UTC' {} +
cp "$FIXTURES_DIR/success-session.jsonl" "$temp_home/sessions/codex/jst-boundary.jsonl"
touch -d '2026-07-09 16:30:00 UTC' "$temp_home/sessions/codex/jst-boundary.jsonl"

run_report() {
  HOME="$temp_home" \
  AI_RETRO_CODEX_ROOT="$temp_home/sessions/codex" \
  AI_RETRO_CLAUDE_ROOT="$temp_home/sessions/claude" \
  AI_RETRO_PI_ROOT="$temp_home/sessions/pi-missing" \
  AI_RETRO_CURSOR_ROOT="$temp_home/sessions/cursor-missing" \
  AI_RETRO_TASK_BOARD_ROOT="$temp_home/task-board" \
    "$SCRIPTS_DIR/generate-report.sh" --date 2026-07-10 --time-zone Asia/Tokyo --output-root "$temp_home/output"
}

assert "source inventory reports unavailable sources without failing" \
  bash -c "HOME='$temp_home' AI_RETRO_CODEX_ROOT='$temp_home/sessions/codex' AI_RETRO_PI_ROOT='$temp_home/missing' '$SCRIPTS_DIR/session-files.sh' sources | grep -q $'pi\\tmissing'"

assert "mixed fixtures generate an artifact" run_report
artifact="$temp_home/output/2026-07-10"
assert "report contains successful operation section" grep -q '^## うまくいった運用' "$artifact/report.md"
assert "explicit completion events are counted" grep -q ':completed-sessions 2' "$artifact/run-summary.edn"
assert "same failure category produces a grounded proposal" grep -q '同じ失敗分類 permission を持つsessionが複数（2 件）' "$artifact/report.md"
assert "broken JSONL is isolated and reported" grep -q ':invalid-jsonl 1' "$artifact/run-summary.edn"
assert "target-day boundary uses the requested time zone" grep -q ':session-count {:codex 4 ' "$artifact/run-summary.edn"
assert "available token and latency metrics are aggregated" grep -q ':metrics {:files 2 :token-total 200 :duration-ms-total 500}' "$artifact/run-summary.edn"
assert "missing histories are explicit" grep -q $'pi\tdirectory not found' "$artifact/missing-sources.tsv"
assert "sensitive fixture body is not copied" bash -c "! grep -q 'abcdefghijklmnopqrstuvwxyz12345678' '$artifact/report.md'"
assert "report passes public-output sanitizer" "$SCRIPTS_DIR/sanitize-check.sh" "$artifact/report.md"
assert "proposal count never exceeds three" bash -c "[ \"\$(grep -c '^### 候補' '$artifact/report.md')\" -le 3 ]"
assert "run records that automatic changes are disabled" grep -q ':automatic-changes false' "$artifact/run-summary.edn"

before_count="$(grep -c '^### 候補' "$artifact/report.md")"
assert "same-day rerun succeeds" run_report
after_count="$(grep -c '^### 候補' "$artifact/report.md")"
if [ "$before_count" = "$after_count" ] && [ "$(find "$temp_home/output" -mindepth 1 -maxdepth 1 -type d | wc -l)" -eq 1 ]; then
  pass "same-day rerun replaces one artifact without duplicate proposals"
else
  fail "same-day rerun replaces one artifact without duplicate proposals"
fi

empty_home="$temp_home/empty"
mkdir -p "$empty_home"
if HOME="$empty_home" AI_RETRO_TASK_BOARD_ROOT="$empty_home/missing" \
  "$SCRIPTS_DIR/generate-report.sh" --date 2026-07-10 --dry-run > "$temp_home/empty-report.md"; then
  pass "no-history run degrades to a report"
else
  fail "no-history run degrades to a report"
fi
assert "no-history report explains missing sources" grep -q '欠損ソース数: 6' "$temp_home/empty-report.md"

distinct_home="$temp_home/distinct"
mkdir -p "$distinct_home/codex" "$distinct_home/claude"
cp "$FIXTURES_DIR/failed-session.jsonl" "$distinct_home/codex/permission.jsonl"
cp "$FIXTURES_DIR/timeout-session.jsonl" "$distinct_home/claude/timeout.jsonl"
find "$distinct_home" -type f -exec touch -d '2026-07-10 12:00:00 UTC' {} +
HOME="$distinct_home" \
AI_RETRO_CODEX_ROOT="$distinct_home/codex" \
AI_RETRO_CLAUDE_ROOT="$distinct_home/claude" \
AI_RETRO_PI_ROOT="$distinct_home/missing-pi" \
AI_RETRO_CURSOR_ROOT="$distinct_home/missing-cursor" \
AI_RETRO_TASK_BOARD_ROOT="$distinct_home/missing-task-board" \
  "$SCRIPTS_DIR/generate-report.sh" --date 2026-07-10 --time-zone Asia/Tokyo --output-root "$distinct_home/output" >/dev/null
assert "different one-off failure categories do not produce a recurring-failure proposal" \
  bash -c "! grep -q '^### 候補[0-9]*: structured-failure-review' '$distinct_home/output/2026-07-10/report.md'"

incomplete_home="$temp_home/incomplete"
mkdir -p "$incomplete_home/codex"
cp "$FIXTURES_DIR/incomplete-session.jsonl" "$incomplete_home/codex/incomplete.jsonl"
touch -d '2026-07-10 12:00:00 UTC' "$incomplete_home/codex/incomplete.jsonl"
HOME="$incomplete_home" \
AI_RETRO_CODEX_ROOT="$incomplete_home/codex" \
AI_RETRO_CLAUDE_ROOT="$incomplete_home/missing-claude" \
AI_RETRO_PI_ROOT="$incomplete_home/missing-pi" \
AI_RETRO_CURSOR_ROOT="$incomplete_home/missing-cursor" \
AI_RETRO_TASK_BOARD_ROOT="$incomplete_home/missing-task-board" \
  "$SCRIPTS_DIR/generate-report.sh" --date 2026-07-10 --time-zone Asia/Tokyo --output-root "$incomplete_home/output" >/dev/null
assert "assistant progress response is not counted as completion" \
  grep -q ':completed-sessions 0' "$incomplete_home/output/2026-07-10/run-summary.edn"

if [ "$failed" -eq 0 ]; then echo "All tests passed"; else echo "$failed tests failed"; fi
exit "$failed"
