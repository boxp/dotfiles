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
assert "same failure category produces a grounded proposal" \
  grep -Eq '^- 分類キー: permission:filesystem:signature-[0-9a-f]{12}$' "$artifact/report.md"
assert "grounded proposal includes the distinct session count" \
  grep -q '^- distinct session件数: 2$' "$artifact/report.md"
assert "grounded proposal includes only sanitized session identifiers" \
  grep -Eq '^- 根拠識別子: (codex|claude):[0-9a-f]{12}, (codex|claude):[0-9a-f]{12}$' "$artifact/report.md"
assert "broken JSONL is isolated and reported" grep -q ':invalid-jsonl 1' "$artifact/run-summary.edn"
assert "target-day boundary uses the requested time zone" grep -q ':session-count {:codex 4 ' "$artifact/run-summary.edn"
assert "available token and latency metrics are aggregated" grep -q ':metrics {:files 2 :token-total 200 :duration-ms-total 500}' "$artifact/run-summary.edn"
assert "missing histories are explicit" grep -q $'pi\tdirectory not found' "$artifact/missing-sources.tsv"
assert "sensitive fixture body is not copied" bash -c "! grep -q 'abcdefghijklmnopqrstuvwxyz12345678' '$artifact/report.md'"
assert "report passes public-output sanitizer" "$SCRIPTS_DIR/sanitize-check.sh" "$artifact/report.md"
assert "proposal count never exceeds three" bash -c "[ \"\$(grep -c '^### 候補' '$artifact/report.md')\" -le 3 ]"
assert "every generated proposal describes the concrete change" \
  bash -c "[ \"\$(grep -c '^### 候補' '$artifact/report.md')\" -eq \"\$(grep -c '^- 変更内容: ' '$artifact/report.md')\" ]"
assert "run records that automatic changes are disabled" grep -q ':automatic-changes false' "$artifact/run-summary.edn"

if HOME="$temp_home" "$SCRIPTS_DIR/generate-report.sh" --date 2026-07-10 --time-zone Not/A-Real-Zone --dry-run > /dev/null 2>&1; then
  fail "invalid IANA time zone is rejected"
else
  pass "invalid IANA time zone is rejected"
fi

langfuse_adapter="$temp_home/langfuse-adapter.sh"
cp "$FIXTURES_DIR/langfuse-adapter.sh" "$langfuse_adapter"
chmod +x "$langfuse_adapter"
langfuse_home="$temp_home/langfuse"
mkdir -p "$langfuse_home"
HOME="$langfuse_home" \
AI_RETRO_LANGFUSE_ADAPTER="$langfuse_adapter" \
AI_RETRO_CODEX_ROOT="$langfuse_home/missing-codex" \
AI_RETRO_CLAUDE_ROOT="$langfuse_home/missing-claude" \
AI_RETRO_PI_ROOT="$langfuse_home/missing-pi" \
AI_RETRO_CURSOR_ROOT="$langfuse_home/missing-cursor" \
AI_RETRO_TASK_BOARD_ROOT="$langfuse_home/missing-task-board" \
  "$SCRIPTS_DIR/generate-report.sh" --date 2026-07-10 --time-zone Asia/Tokyo --output-root "$langfuse_home/output" >/dev/null
langfuse_artifact="$langfuse_home/output/2026-07-10"
assert "available Langfuse adapter is executed and target-day traces are counted" \
  grep -q ':langfuse-traces 1' "$langfuse_artifact/run-summary.edn"
assert "Langfuse timestamps with out-of-range UTC offsets are rejected" \
  grep -q $'^langfuse\tadapter returned 1 invalid records$' "$langfuse_artifact/missing-sources.tsv"
assert "Langfuse raw trace identifiers are not persisted" \
  bash -c "! grep -R -q 'private-trace-id' '$langfuse_artifact'"

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

same_cause_home="$temp_home/same-cause"
mkdir -p "$same_cause_home/codex" "$same_cause_home/claude"
cp "$FIXTURES_DIR/nonzero-same-cause-a.jsonl" "$same_cause_home/codex/cache-a.jsonl"
cp "$FIXTURES_DIR/nonzero-same-cause-b.jsonl" "$same_cause_home/claude/cache-b.jsonl"
HOME="$same_cause_home" \
AI_RETRO_CODEX_ROOT="$same_cause_home/codex" \
AI_RETRO_CLAUDE_ROOT="$same_cause_home/claude" \
AI_RETRO_PI_ROOT="$same_cause_home/missing-pi" \
AI_RETRO_CURSOR_ROOT="$same_cause_home/missing-cursor" \
AI_RETRO_TASK_BOARD_ROOT="$same_cause_home/missing-task-board" \
  "$SCRIPTS_DIR/generate-report.sh" --date 2026-07-10 --time-zone Asia/Tokyo --output-root "$same_cause_home/output" >/dev/null
same_cause_report="$same_cause_home/output/2026-07-10/report.md"
assert "volatile timestamps, record IDs, and temp paths normalize to one nonzero cause" \
  grep -Eq '^- 分類キー: nonzero-exit:code-17:signature-[0-9a-f]{12} / distinct session件数: 2 / 識別子: (codex|claude):[0-9a-f]{12}, (codex|claude):[0-9a-f]{12}$' "$same_cause_report"
assert "the normalized nonzero cause becomes a grounded proposal" \
  grep -Eq '^- 分類キー: nonzero-exit:code-17:signature-[0-9a-f]{12}$' "$same_cause_report"
assert "raw nonzero output and temp paths are not written to artifacts" \
  bash -c "! grep -R -Eq 'cache index corrupt|/tmp/ai-retro' '$same_cause_home/output/2026-07-10'"

different_exit_home="$temp_home/different-exit"
mkdir -p "$different_exit_home/codex" "$different_exit_home/claude"
cp "$FIXTURES_DIR/nonzero-different-cause-a.jsonl" "$different_exit_home/codex/compiler.jsonl"
cp "$FIXTURES_DIR/nonzero-different-cause-b.jsonl" "$different_exit_home/claude/tests.jsonl"
HOME="$different_exit_home" \
AI_RETRO_CODEX_ROOT="$different_exit_home/codex" \
AI_RETRO_CLAUDE_ROOT="$different_exit_home/claude" \
AI_RETRO_PI_ROOT="$different_exit_home/missing-pi" \
AI_RETRO_CURSOR_ROOT="$different_exit_home/missing-cursor" \
AI_RETRO_TASK_BOARD_ROOT="$different_exit_home/missing-task-board" \
  "$SCRIPTS_DIR/generate-report.sh" --date 2026-07-10 --time-zone Asia/Tokyo --output-root "$different_exit_home/output" >/dev/null
different_exit_report="$different_exit_home/output/2026-07-10/report.md"
assert "different nonzero causes have two distinct singleton signatures" \
  bash -c "[ \"\$(grep -Ec '^- 分類キー: nonzero-exit:code-5:signature-[0-9a-f]{12} / distinct session件数: 1 ' '$different_exit_report')\" -eq 2 ]"
assert "different singleton nonzero causes do not become recurring proposals" \
  bash -c "! grep -q '^### 候補[0-9]*: structured-failure-review' '$different_exit_report'"

repeated_home="$temp_home/repeated-session"
mkdir -p "$repeated_home/codex"
cp "$FIXTURES_DIR/nonzero-repeated-session.jsonl" "$repeated_home/codex/repeated.jsonl"
HOME="$repeated_home" \
AI_RETRO_CODEX_ROOT="$repeated_home/codex" \
AI_RETRO_CLAUDE_ROOT="$repeated_home/missing-claude" \
AI_RETRO_PI_ROOT="$repeated_home/missing-pi" \
AI_RETRO_CURSOR_ROOT="$repeated_home/missing-cursor" \
AI_RETRO_TASK_BOARD_ROOT="$repeated_home/missing-task-board" \
  "$SCRIPTS_DIR/generate-report.sh" --date 2026-07-10 --time-zone Asia/Tokyo --output-root "$repeated_home/output" >/dev/null
repeated_report="$repeated_home/output/2026-07-10/report.md"
assert "duplicate records in one session count once" \
  grep -Eq '^- 分類キー: nonzero-exit:code-17:signature-[0-9a-f]{12} / distinct session件数: 1 ' "$repeated_report"
assert "one session repeating a failure does not become a recurring proposal" \
  bash -c "! grep -q '^### 候補[0-9]*: structured-failure-review' '$repeated_report'"

unknown_home="$temp_home/unknown-fallback"
mkdir -p "$unknown_home/codex" "$unknown_home/claude"
cp "$FIXTURES_DIR/unknown-failure-a.jsonl" "$unknown_home/codex/unknown-a.jsonl"
cp "$FIXTURES_DIR/unknown-failure-b.jsonl" "$unknown_home/claude/unknown-b.jsonl"
HOME="$unknown_home" \
AI_RETRO_CODEX_ROOT="$unknown_home/codex" \
AI_RETRO_CLAUDE_ROOT="$unknown_home/claude" \
AI_RETRO_PI_ROOT="$unknown_home/missing-pi" \
AI_RETRO_CURSOR_ROOT="$unknown_home/missing-cursor" \
AI_RETRO_TASK_BOARD_ROOT="$unknown_home/missing-task-board" \
  "$SCRIPTS_DIR/generate-report.sh" --date 2026-07-10 --time-zone Asia/Tokyo --output-root "$unknown_home/output" >/dev/null
unknown_report="$unknown_home/output/2026-07-10/report.md"
assert "object-valued error causes normalize JSON-quoted request and call IDs into one unknown fallback" \
  grep -Eq '^- 分類キー: unknown:signature-[0-9a-f]{12} / distinct session件数: 2 ' "$unknown_report"
assert "unknown fallback output does not expose the raw failure" \
  bash -c "! grep -R -Eq 'opaque subsystem fault|/tmp/unknown' '$unknown_home/output/2026-07-10'"

string_message_home="$temp_home/string-message"
mkdir -p "$string_message_home/codex"
cp "$FIXTURES_DIR/string-message-failure.jsonl" "$string_message_home/codex/failure.jsonl"
HOME="$string_message_home" \
AI_RETRO_CODEX_ROOT="$string_message_home/codex" \
AI_RETRO_CLAUDE_ROOT="$string_message_home/missing-claude" \
AI_RETRO_PI_ROOT="$string_message_home/missing-pi" \
AI_RETRO_CURSOR_ROOT="$string_message_home/missing-cursor" \
AI_RETRO_TASK_BOARD_ROOT="$string_message_home/missing-task-board" \
  "$SCRIPTS_DIR/generate-report.sh" --date 2026-07-10 --time-zone Asia/Tokyo --output-root "$string_message_home/output" >/dev/null
assert "string-valued payloads/messages are safe and numeric string tool exits are classified once" \
  bash -c "[ \"\$(grep -Ec '^- 分類キー: nonzero-exit:code-17:signature-[0-9a-f]{12} / distinct session件数: 1 ' '$string_message_home/output/2026-07-10/report.md')\" -eq 1 ]"

ranking_home="$temp_home/ranking"
mkdir -p "$ranking_home/codex" "$ranking_home/claude"
cp "$FIXTURES_DIR/failed-session.jsonl" "$ranking_home/codex/permission-a.jsonl"
cp "$FIXTURES_DIR/failed-session.jsonl" "$ranking_home/claude/permission-b.jsonl"
cp "$FIXTURES_DIR/failed-session.jsonl" "$ranking_home/claude/permission-c.jsonl"
cp "$FIXTURES_DIR/timeout-session.jsonl" "$ranking_home/codex/timeout-a.jsonl"
cp "$FIXTURES_DIR/timeout-session.jsonl" "$ranking_home/claude/timeout-b.jsonl"
cp "$FIXTURES_DIR/nonzero-same-cause-a.jsonl" "$ranking_home/codex/cache-a.jsonl"
cp "$FIXTURES_DIR/nonzero-same-cause-b.jsonl" "$ranking_home/claude/cache-b.jsonl"
cp "$FIXTURES_DIR/unknown-failure-a.jsonl" "$ranking_home/codex/unknown-a.jsonl"
cp "$FIXTURES_DIR/unknown-failure-b.jsonl" "$ranking_home/claude/unknown-b.jsonl"
HOME="$ranking_home" \
AI_RETRO_CODEX_ROOT="$ranking_home/codex" \
AI_RETRO_CLAUDE_ROOT="$ranking_home/claude" \
AI_RETRO_PI_ROOT="$ranking_home/missing-pi" \
AI_RETRO_CURSOR_ROOT="$ranking_home/missing-cursor" \
AI_RETRO_TASK_BOARD_ROOT="$ranking_home/missing-task-board" \
  "$SCRIPTS_DIR/generate-report.sh" --date 2026-07-10 --time-zone Asia/Tokyo --output-root "$ranking_home/output" >/dev/null
ranking_report="$ranking_home/output/2026-07-10/report.md"
ranking_keys="$(awk '
  /^### 候補[0-9]+: structured-failure-review$/ { candidate = 1; next }
  candidate && /^- 分類キー: / { sub(/^- 分類キー: /, ""); print; candidate = 0 }
' "$ranking_report")"
assert "recurring categories consume no more than the three proposal slots" \
  bash -c "[ \"\$(printf '%s\\n' '$ranking_keys' | grep -c .)\" -eq 3 ]"
assert "recurring categories sort by count descending first" \
  bash -c "printf '%s\\n' '$ranking_keys' | sed -n '1p' | grep -Eq '^permission:filesystem:signature-[0-9a-f]{12}$'"
assert "equal-count recurring categories then sort by category key" \
  bash -c "printf '%s\\n' '$ranking_keys' | sed -n '2p' | grep -Eq '^nonzero-exit:code-17:signature-[0-9a-f]{12}$' && printf '%s\\n' '$ranking_keys' | sed -n '3p' | grep -Eq '^timeout:operation:signature-[0-9a-f]{12}$'"

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
assert "assistant progress and turn_completed are not counted as task completion" \
  grep -q ':completed-sessions 0' "$incomplete_home/output/2026-07-10/run-summary.edn"

timestamp_home="$temp_home/timestamp-filter"
mkdir -p "$timestamp_home/codex"
cp "$FIXTURES_DIR/cross-day-session.jsonl" "$timestamp_home/codex/cross-day.jsonl"
# Its mtime is deliberately inside the target day; timestamped records must win.
touch -d '2026-07-10 12:00:00 UTC' "$timestamp_home/codex/cross-day.jsonl"
cp "$FIXTURES_DIR/success-session.jsonl" "$timestamp_home/codex/restored-later.jsonl"
# A restored file with an out-of-day mtime must still be selected by event time.
touch -d '2026-07-12 12:00:00 UTC' "$timestamp_home/codex/restored-later.jsonl"
TZ=Asia/Tokyo \
HOME="$timestamp_home" \
AI_RETRO_CODEX_ROOT="$timestamp_home/codex" \
AI_RETRO_CLAUDE_ROOT="$timestamp_home/missing-claude" \
AI_RETRO_PI_ROOT="$timestamp_home/missing-pi" \
AI_RETRO_CURSOR_ROOT="$timestamp_home/missing-cursor" \
AI_RETRO_TASK_BOARD_ROOT="$timestamp_home/missing-task-board" \
  "$SCRIPTS_DIR/generate-report.sh" --date 2026-07-10 --time-zone Asia/Tokyo --output-root "$timestamp_home/output" >/dev/null
timestamp_artifact="$timestamp_home/output/2026-07-10"
assert "ISO offsets, fractional seconds, and numeric epoch milliseconds are included" \
  grep -q ':metrics {:files 2 :token-total 175 :duration-ms-total 375}' "$timestamp_artifact/run-summary.edn"
assert "ISO timestamps are converted as UTC even when the host timezone is not UTC" \
  grep -q ':session-count {:codex 2 ' "$timestamp_artifact/run-summary.edn"
assert "records outside the target day do not contribute completion state" \
  grep -q ':completed-sessions 1' "$timestamp_artifact/run-summary.edn"
assert "event time includes a target-day session restored on a later day" \
  grep -q ':session-count {:codex 2 ' "$timestamp_artifact/run-summary.edn"
assert "unparseable timestamps and outside-day failures are not counted through mtime" \
  grep -q '構造化されたerror / failed status / tool errorを持つセッションが 1 件' "$timestamp_artifact/report.md"
assert "unparseable timestamp records have an explicit sanitized missing reason" \
  grep -Eq $'^codex\tcodex:[0-9a-f]{12} has 1 records with unparseable timestamps$' "$timestamp_artifact/missing-sources.tsv"

legacy_home="$temp_home/legacy-mtime"
mkdir -p "$legacy_home/codex"
cp "$FIXTURES_DIR/no-timestamp-session.jsonl" "$legacy_home/codex/legacy.jsonl"
touch -d '2026-07-10 12:00:00 UTC' "$legacy_home/codex/legacy.jsonl"
HOME="$legacy_home" \
AI_RETRO_CODEX_ROOT="$legacy_home/codex" \
AI_RETRO_CLAUDE_ROOT="$legacy_home/missing-claude" \
AI_RETRO_PI_ROOT="$legacy_home/missing-pi" \
AI_RETRO_CURSOR_ROOT="$legacy_home/missing-cursor" \
AI_RETRO_TASK_BOARD_ROOT="$legacy_home/missing-task-board" \
  "$SCRIPTS_DIR/generate-report.sh" --date 2026-07-10 --time-zone Asia/Tokyo --output-root "$legacy_home/output" >/dev/null
assert "formats without timestamp fields fall back to file mtime" \
  grep -q ':completed-sessions 1' "$legacy_home/output/2026-07-10/run-summary.edn"

wrong_day_home="$temp_home/wrong-day-mtime"
mkdir -p "$wrong_day_home/codex"
cp "$FIXTURES_DIR/success-session.jsonl" "$wrong_day_home/codex/touched-later.jsonl"
touch -d '2026-07-11 12:00:00 UTC' "$wrong_day_home/codex/touched-later.jsonl"
cp "$FIXTURES_DIR/invalid-timestamp-session.jsonl" "$wrong_day_home/codex/invalid-timestamp.jsonl"
touch -d '2026-07-11 12:00:00 UTC' "$wrong_day_home/codex/invalid-timestamp.jsonl"
HOME="$wrong_day_home" \
AI_RETRO_CODEX_ROOT="$wrong_day_home/codex" \
AI_RETRO_CLAUDE_ROOT="$wrong_day_home/missing-claude" \
AI_RETRO_PI_ROOT="$wrong_day_home/missing-pi" \
AI_RETRO_CURSOR_ROOT="$wrong_day_home/missing-cursor" \
AI_RETRO_TASK_BOARD_ROOT="$wrong_day_home/missing-task-board" \
  "$SCRIPTS_DIR/generate-report.sh" --date 2026-07-11 --time-zone Asia/Tokyo --output-root "$wrong_day_home/output" >/dev/null
assert "mtime cannot pull another day's timestamped session into the report" \
  grep -q ':session-count {:codex 0 ' "$wrong_day_home/output/2026-07-11/run-summary.edn"
assert "invalid-timestamp-only sessions retain a sanitized inventory entry" \
  grep -Eq $'^codex\tcodex:[0-9a-f]{12}\tinvalid-timestamp$' "$wrong_day_home/output/2026-07-11/input-inventory.tsv"
assert "calendar-invalid dates and out-of-range offsets are reported as invalid" \
  grep -Eq $'^codex\tcodex:[0-9a-f]{12} has 3 records with unparseable timestamps$' "$wrong_day_home/output/2026-07-11/missing-sources.tsv"

if [ "$failed" -eq 0 ]; then echo "All tests passed"; else echo "$failed tests failed"; fi
exit "$failed"
