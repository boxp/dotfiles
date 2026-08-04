#!/usr/bin/env bash
# Run one delegated AI CLI invocation and leave a durable result for the delegator.
set -uo pipefail

usage() {
  echo "Usage: $0 --session-id ID --working-directory DIR [--state-root DIR] [--format-stream auto|claude|cursor|pi|off] -- command [args...]" >&2
  exit 2
}

detect_format_stream() {
  case "${1:-}" in
    claude) printf 'claude\n' ;;
    cursor-agent) printf 'cursor\n' ;;
    pi) printf 'off\n' ;;
    *) printf 'off\n' ;;
  esac
}

session_id=""
working_directory=""
state_root="${AI_DELEGATE_STATE_ROOT:-/tmp/ai-delegate}"
format_stream="${AI_DELEGATE_FORMAT_STREAM:-auto}"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --session-id) session_id="${2:-}"; shift 2 ;;
    --working-directory) working_directory="${2:-}"; shift 2 ;;
    --state-root) state_root="${2:-}"; shift 2 ;;
    --format-stream) format_stream="${2:-}"; shift 2 ;;
    --) shift; break ;;
    *) usage ;;
  esac
done

[ -n "$session_id" ] && [ -n "$working_directory" ] && [ "$#" -gt 0 ] || usage
case "$session_id" in
  *[!A-Za-z0-9._-]*|'') echo "Invalid session ID: $session_id" >&2; exit 2 ;;
esac
[ -d "$working_directory" ] || { echo "Working directory does not exist: $working_directory" >&2; exit 2; }

umask 077
state_dir="$state_root/$session_id"
mkdir -p "$state_dir"
log_file="$state_dir/output.log"

write_file() {
  local path="$1" value="$2" temp
  temp="${path}.tmp.$$"
  printf '%s\n' "$value" > "$temp"
  mv "$temp" "$path"
}

set_pane_option() {
  local key="$1" value="$2"
  if [ -n "${TMUX_PANE:-}" ] && command -v tmux >/dev/null 2>&1; then
    tmux set-option -p -t "$TMUX_PANE" "$key" "$value" 2>/dev/null || true
  fi
}

notify() {
  local title="$1" message="$2"
  command -v osascript >/dev/null 2>&1 || return 0
  osascript -e "display notification \"${message//\"/\\\"}\" with title \"${title//\"/\\\"}\"" >/dev/null 2>&1 || true
}

started_at="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
write_file "$state_dir/started_at" "$started_at"
write_file "$state_dir/working_directory" "$working_directory"
write_file "$state_dir/command" "$(printf '%q ' "$@")"
write_file "$state_dir/status" running
set_pane_option @ai_delegate_session_id "$session_id"
set_pane_option @ai_delegate_state_dir "$state_dir"
set_pane_option @ai_delegate_status running
printf '[%s] delegate started: %s\n' "$started_at" "$(printf '%q ' "$@")" >> "$log_file"

script_dir="$(cd "$(dirname "$0")" && pwd)"
format_script="$script_dir/format-stream.sh"
resolved_format="$format_stream"
if [ "$resolved_format" = "auto" ]; then
  resolved_format="$(detect_format_stream "${1:-}")"
fi

set +e
if [ "$resolved_format" != "off" ] && [ -x "$format_script" ]; then
  (
    cd "$working_directory" && "$@"
  ) 2>&1 | stdbuf -oL "$format_script" "$resolved_format" | tee -a "$log_file"
else
  (
    cd "$working_directory" && "$@"
  ) 2>&1 | tee -a "$log_file"
fi
command_status=${PIPESTATUS[0]}
set -e

finished_at="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
write_file "$state_dir/finished_at" "$finished_at"
write_file "$state_dir/exit_code" "$command_status"
if [ "$command_status" -eq 0 ]; then
  result=success
  notification_title="AI delegate completed"
else
  result=failed
  notification_title="AI delegate failed"
fi
write_file "$state_dir/status" "$result"
set_pane_option @ai_delegate_status "$result"
printf '[%s] delegate %s (exit %s)\n' "$finished_at" "$result" "$command_status" >> "$log_file"
notify "$notification_title" "$session_id ($result; exit $command_status)"
exit "$command_status"
