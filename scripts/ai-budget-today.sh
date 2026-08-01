#!/usr/bin/env bash
# Print today's remaining AI budget allowance from AI_MONTHLY_BUDGET.
# Outputs nothing when budget is unset, invalid, or cost data is unavailable.

set -euo pipefail

exec 2>/dev/null

TMUX_SEGMENT=false
if [[ "${1:-}" == "--tmux-segment" ]]; then
  TMUX_SEGMENT=true
fi

validate_budget() {
  local budget="$1"
  [[ -n "$budget" ]] || return 1
  [[ "$budget" =~ ^[0-9]+([.][0-9]+)?$ ]] || return 1
  return 0
}

reference_date() {
  if [[ -n "${AI_BUDGET_TEST_DATE:-}" ]]; then
    printf '%s\n' "$AI_BUDGET_TEST_DATE"
    return 0
  fi
  date +%Y-%m-%d
}

days_remaining_in_month() {
  local ref_date="$1"
  local year month day last_day first_of_month

  year=${ref_date%%-*}
  month=${ref_date#*-}
  month=${month%-*}
  day=${ref_date##*-}
  first_of_month="${year}-${month}-01"

  # GNU date first, then BSD/macOS date, then cal. This used to rely on `cal`
  # alone, which the WSL Ubuntu image does not ship -- the whole segment then
  # died under `set -e` with its stderr already redirected to /dev/null.
  last_day=$(date -d "$first_of_month +1 month -1 day" +%d 2>/dev/null) ||
    last_day=$(date -j -v+1m -v-1d -f %Y-%m-%d "$first_of_month" +%d 2>/dev/null) ||
    last_day=$(cal "$month" "$year" 2>/dev/null | awk 'NF { days = $NF } END { print days }') ||
    return 1

  [[ -n "$last_day" ]] || return 1
  printf '%d\n' $((10#${last_day} - 10#${day} + 1))
}

monthly_total_cost() {
  local ref_date="$1"
  local ccusage_cmd="${AI_BUDGET_CCUSAGE_CMD:-ccusage}"
  local year month since until

  # ccusage-status.sh already fetched the monthly total for its own segment and
  # passes it down, so skip a redundant (~3s, ~200MB) ccusage run.
  if [[ "${AI_BUDGET_MONTHLY_COST:-}" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    printf '%s\n' "$AI_BUDGET_MONTHLY_COST"
    return 0
  fi

  command -v jq >/dev/null 2>&1 || return 1
  command -v "$ccusage_cmd" >/dev/null 2>&1 || return 1

  year=${ref_date%%-*}
  month=${ref_date#*-}
  month=${month%-*}
  since=$(printf '%s-%s-01' "$year" "$month")
  until="$ref_date"

  local json cost
  json=$("$ccusage_cmd" monthly --json --since "$since" --until "$until" 2>/dev/null) || return 1
  [[ -n "$json" ]] || return 1

  cost=$(printf '%s\n' "$json" | jq -er '.totals.totalCost' 2>/dev/null) || return 1
  [[ -n "$cost" && "$cost" != "null" ]] || return 1
  printf '%s\n' "$cost"
}

main() {
  local budget="${AI_MONTHLY_BUDGET:-}"
  validate_budget "$budget" || exit 0

  local ref_date days cost remaining daily formatted
  ref_date=$(reference_date)
  days=$(days_remaining_in_month "$ref_date")
  [[ "$days" -gt 0 ]] || exit 0

  cost=$(monthly_total_cost "$ref_date") || exit 0

  formatted=$(awk -v budget="$budget" -v cost="$cost" -v days="$days" '
    BEGIN {
      remaining = budget - cost
      if (remaining < 0) {
        remaining = 0
      }
      printf "$%.2f", remaining / days
    }
  ')

  if $TMUX_SEGMENT; then
    printf ' | Budget today: %s' "$formatted"
  else
    printf '%s' "$formatted"
  fi
}

main "$@"
