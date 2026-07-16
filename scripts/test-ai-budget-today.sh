#!/usr/bin/env bash
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$TESTS_DIR/ai-budget-today.sh"
failed=0

pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1"; failed=$((failed + 1)); }
assert_eq() {
  local name="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    pass "$name"
  else
    fail "$name (expected '$expected', got '$actual')"
  fi
}

mock_ccusage_dir="$(mktemp -d)"
trap 'rm -rf "$mock_ccusage_dir"' EXIT

write_mock_ccusage() {
  local cost="$1"
  cat >"$mock_ccusage_dir/ccusage" <<EOF
#!/usr/bin/env bash
printf '%s\n' '{"totals":{"totalCost":${cost}}}'
EOF
  chmod +x "$mock_ccusage_dir/ccusage"
}

run_budget() {
  AI_MONTHLY_BUDGET="${1:-}" \
    AI_BUDGET_TEST_DATE="${AI_BUDGET_TEST_DATE:-2026-07-16}" \
    AI_BUDGET_CCUSAGE_CMD="$mock_ccusage_dir/ccusage" \
    "$SCRIPT"
}

write_mock_ccusage 36
assert_eq "unset budget is blank" "" "$(run_budget "")"
assert_eq "invalid budget is blank" "" "$(run_budget "abc")"
assert_eq "valid budget gives two-decimal daily value" '$4.00' "$(run_budget 100)"

write_mock_ccusage 50
assert_eq "exceeded budget is zero dollars" '$0.00' "$(run_budget 40)"

if [[ "$failed" -gt 0 ]]; then
  printf '%d test(s) failed\n' "$failed" >&2
  exit 1
fi

printf 'All tests passed\n'
