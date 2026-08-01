#!/usr/bin/env bash
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$TESTS_DIR/ccusage-status.sh"
failed=0

pass() { printf 'PASS: %s\n' "$1"; }
fail() {
  printf 'FAIL: %s\n' "$1"
  failed=$((failed + 1))
}
assert_eq() {
  local name="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    pass "$name"
  else
    fail "$name (expected '$expected', got '$actual')"
  fi
}

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

mock_ccusage="$work_dir/ccusage"
call_log="$work_dir/calls"
cache_home="$work_dir/cache"
cache_file="$cache_home/tmux-ccusage/segment"

# Mock ccusage: logs every invocation so we can assert on how often the real
# (expensive) binary would have run.
write_mock_ccusage() {
  local month_cost="$1" today_cost="$2" today_tokens="$3" exit_code="${4:-0}" delay="${5:-0}"
  cat >"$mock_ccusage" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$call_log"

if [[ "$delay" != "0" ]]; then
  sleep $delay
fi

if [[ "$exit_code" != "0" ]]; then
  exit $exit_code
fi

case "\$1" in
  daily)
    printf '%s\n' '{"totals":{"totalCost":${today_cost},"totalTokens":${today_tokens}}}'
    ;;
  monthly)
    printf '%s\n' '{"totals":{"totalCost":${month_cost}}}'
    ;;
  *)
    exit 1
    ;;
esac
EOF
  chmod +x "$mock_ccusage"
}

call_count() {
  [[ -r "$call_log" ]] || {
    printf '0\n'
    return 0
  }
  wc -l <"$call_log" | tr -d ' '
}

reset_state() {
  rm -rf "$cache_home" "$call_log"
}

run_status() {
  XDG_CACHE_HOME="$cache_home" \
    TMUX_CCUSAGE_CMD="$mock_ccusage" \
    TMUX_CCUSAGE_TTL="${TMUX_CCUSAGE_TTL:-120}" \
    AI_MONTHLY_BUDGET="${AI_MONTHLY_BUDGET:-}" \
    AI_BUDGET_TEST_DATE="${AI_BUDGET_TEST_DATE:-2026-07-16}" \
    "$SCRIPT" "$@"
}

# Wait for a detached refresh to land rather than sleeping a fixed amount.
wait_for_cache() {
  local deadline=$((SECONDS + 10))
  while ((SECONDS < deadline)); do
    [[ -r "$cache_file" ]] && return 0
    sleep 0.1
  done
  return 1
}

# --- --refresh builds the segment -------------------------------------------
reset_state
write_mock_ccusage 36 1.5 456789
assert_eq "refresh builds the full segment" \
  'Month: $36.00 | Today: $1.50 456K | Budget today: $4.00' \
  "$(AI_MONTHLY_BUDGET=100 run_status --refresh && cat "$cache_file")"

assert_eq "refresh runs ccusage exactly twice" "2" "$(call_count)"

# --- reading a fresh cache must not touch ccusage ----------------------------
rm -f "$call_log"
assert_eq "fresh cache is served verbatim" \
  'Month: $36.00 | Today: $1.50 456K | Budget today: $4.00' \
  "$(AI_MONTHLY_BUDGET=100 run_status)"

assert_eq "fresh cache spawns no ccusage" "0" "$(call_count)"

# --- token formatting --------------------------------------------------------
reset_state
write_mock_ccusage 0 0 2500000
run_status --refresh
assert_eq "millions of tokens use the M suffix" \
  'Month: $0.00 | Today: $0.00 2M' "$(cat "$cache_file")"

reset_state
write_mock_ccusage 0 0 999
run_status --refresh
assert_eq "small token counts stay raw" \
  'Month: $0.00 | Today: $0.00 999' "$(cat "$cache_file")"

# --- an expired cache refreshes in the background ---------------------------
reset_state
write_mock_ccusage 10 2 1000
run_status --refresh
touch -d '2 hours ago' "$cache_file"
write_mock_ccusage 20 3 2000

stale_output="$(run_status)"
assert_eq "expired cache still answers immediately with the old value" \
  'Month: $10.00 | Today: $2.00 1000' "$stale_output"

rm -f "$call_log"
touch -d '2 hours ago' "$cache_file"
run_status >/dev/null
deadline=$((SECONDS + 10))
while ((SECONDS < deadline)); do
  [[ "$(cat "$cache_file")" == 'Month: $20.00 | Today: $3.00 2K' ]] && break
  sleep 0.1
done
assert_eq "background refresh updates the cache" \
  'Month: $20.00 | Today: $3.00 2K' "$(cat "$cache_file")"

# --- redraws during a stale window must not pile up refreshes ---------------
reset_state
write_mock_ccusage 7 1 100 0 1
run_status --refresh
touch -d '2 hours ago' "$cache_file"
rm -f "$call_log"

for _ in 1 2 3 4 5; do
  run_status >/dev/null
done

deadline=$((SECONDS + 15))
while ((SECONDS < deadline)); do
  [[ -d "$cache_home/tmux-ccusage/refresh.lock" ]] || break
  sleep 0.1
done
assert_eq "five redraws during a stale window run one refresh" "2" "$(call_count)"

# --- a failing ccusage must not blank the status line ------------------------
write_mock_ccusage 0 0 0 1
before="$(cat "$cache_file")"
run_status --refresh >/dev/null 2>&1 || true
assert_eq "failed refresh preserves the previous cache" "$before" "$(cat "$cache_file")"

# --- no cache yet ------------------------------------------------------------
reset_state
write_mock_ccusage 5 1 100
assert_eq "missing cache falls back to a placeholder" \
  'Month: -- | Today: --' "$(run_status)"
wait_for_cache || fail "background refresh never produced a cache"

if [[ "$failed" -gt 0 ]]; then
  printf '%d test(s) failed\n' "$failed" >&2
  exit 1
fi

printf 'All tests passed\n'
