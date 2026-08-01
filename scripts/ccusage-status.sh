#!/usr/bin/env bash
# Emit the ccusage portion of the tmux status line from a cache.
#
# The upstream tmux-ccusage plugin expands every #{ccusage_*} interpolation into
# its own shell script and none of them cache, so each status redraw spawned
# several ~3s / ~200MB Node processes. Under `status-interval 1` those
# generations overlapped and permanently occupied roughly 10 CPU cores, which on
# WSL2 starved the Windows host. Here the status line only reads a cache file
# and ccusage runs at most once per TTL in a detached refresh.

set -uo pipefail

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/tmux-ccusage"
CACHE_FILE="$CACHE_DIR/segment"
LOCK_DIR="$CACHE_DIR/refresh.lock"
CACHE_TTL="${TMUX_CCUSAGE_TTL:-120}"
PLACEHOLDER='Month: -- | Today: --'
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Locate the ccusage binary. Unlike the plugin's helper this never probes with
# `npx ccusage --version`, which doubled the Node startups per segment.
resolve_ccusage() {
  local candidate

  if [[ -n "${TMUX_CCUSAGE_CMD:-}" ]]; then
    printf '%s\n' "$TMUX_CCUSAGE_CMD"
    return 0
  fi

  if candidate=$(command -v ccusage 2>/dev/null); then
    printf '%s\n' "$candidate"
    return 0
  fi

  for candidate in \
    "$HOME/.nodebrew/current/bin/ccusage" \
    "$HOME/.local/bin/ccusage" \
    /usr/local/bin/ccusage \
    /opt/homebrew/bin/ccusage; do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

format_cost() {
  local cost="$1"

  if [[ ! "$cost" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    printf '$0.00'
    return 0
  fi

  printf '$%.2f' "$cost"
}

format_tokens() {
  local tokens="$1"

  if [[ ! "$tokens" =~ ^[0-9]+$ ]] || ((tokens == 0)); then
    printf '0'
  elif ((tokens > 1000000)); then
    printf '%dM' $((tokens / 1000000))
  elif ((tokens > 1000)); then
    printf '%dK' $((tokens / 1000))
  else
    printf '%d' "$tokens"
  fi
}

# Rebuild the cached segment. Leaves the previous cache untouched on failure so
# a transient ccusage error never blanks the status line.
refresh() {
  local ccusage today month_start daily_json monthly_json
  local month_cost today_cost today_tokens budget_segment segment tmp

  command -v jq >/dev/null 2>&1 || return 1
  ccusage=$(resolve_ccusage) || return 1

  today=$(date +%Y%m%d)
  month_start="$(date +%Y%m)01"

  daily_json=$("$ccusage" daily --json --since "$today" --until "$today" 2>/dev/null) || return 1
  monthly_json=$("$ccusage" monthly --json --since "$month_start" --until "$today" 2>/dev/null) || return 1

  month_cost=$(printf '%s' "$monthly_json" | jq -er '.totals.totalCost // 0') || return 1
  today_cost=$(printf '%s' "$daily_json" | jq -er '.totals.totalCost // 0') || return 1
  today_tokens=$(printf '%s' "$daily_json" | jq -er '.totals.totalTokens // 0') || return 1

  # The budget segment needs the same monthly total, so hand it over instead of
  # letting ai-budget-today.sh spend a third ccusage run on it.
  budget_segment=""
  if [[ -x "$SCRIPT_DIR/ai-budget-today.sh" ]]; then
    budget_segment=$(
      AI_BUDGET_MONTHLY_COST="$month_cost" \
        AI_BUDGET_CCUSAGE_CMD="$ccusage" \
        "$SCRIPT_DIR/ai-budget-today.sh" --tmux-segment 2>/dev/null
    ) || budget_segment=""
  fi

  segment="Month: $(format_cost "$month_cost") | Today: $(format_cost "$today_cost") $(format_tokens "$today_tokens")${budget_segment}"

  mkdir -p "$CACHE_DIR" 2>/dev/null || return 1
  tmp=$(mktemp "$CACHE_DIR/segment.XXXXXX") || return 1
  if ! printf '%s\n' "$segment" >"$tmp"; then
    rm -f "$tmp"
    return 1
  fi
  mv -f "$tmp" "$CACHE_FILE" || {
    rm -f "$tmp"
    return 1
  }
}

cache_is_fresh() {
  local mtime now

  [[ -r "$CACHE_FILE" ]] || return 1
  mtime=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || stat -f %m "$CACHE_FILE" 2>/dev/null) || return 1
  now=$(date +%s)

  ((now - mtime < CACHE_TTL))
}

# mkdir is atomic on every POSIX filesystem, unlike flock which a stock macOS
# does not ship. Without a lock here every redraw during a stale window would
# start its own refresh and rebuild the very CPU spike this script removes.
# A lock older than the TTL is treated as stale and reclaimed.
acquire_lock() {
  local mtime now

  if mkdir "$LOCK_DIR" 2>/dev/null; then
    return 0
  fi

  mtime=$(stat -c %Y "$LOCK_DIR" 2>/dev/null || stat -f %m "$LOCK_DIR" 2>/dev/null) || return 1
  now=$(date +%s)
  ((now - mtime > CACHE_TTL)) || return 1

  rmdir "$LOCK_DIR" 2>/dev/null || return 1
  mkdir "$LOCK_DIR" 2>/dev/null
}

# tmux reads this script's stdout, so the refresh must not keep that descriptor
# open — otherwise the redraw would block until ccusage finishes.
kick_refresh() {
  acquire_lock || return 0

  (
    trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT
    refresh
  ) >/dev/null 2>&1 </dev/null &
  disown 2>/dev/null || true
}

main() {
  mkdir -p "$CACHE_DIR" 2>/dev/null || true

  case "${1:-}" in
    --refresh)
      refresh
      return $?
      ;;
    --tmux-segment | "") ;;
    *)
      printf 'usage: %s [--refresh|--tmux-segment]\n' "${0##*/}" >&2
      return 2
      ;;
  esac

  cache_is_fresh || kick_refresh

  if [[ -r "$CACHE_FILE" ]]; then
    cat "$CACHE_FILE"
  else
    printf '%s\n' "$PLACEHOLDER"
  fi
}

main "$@"
