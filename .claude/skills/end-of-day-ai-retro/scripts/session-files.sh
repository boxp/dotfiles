#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
session-files.sh list [--date YYYY-MM-DD] [--agent codex|claude|pi|cursor|all] [--limit N]
session-files.sh retro [--date YYYY-MM-DD] [--limit N] [--top N]
session-files.sh show <session-file> [--lines N]

Lists local AI agent session files for end-of-day retrospectives.
USAGE
}

command="${1:-}"
[ -n "$command" ] || {
  usage
  exit 1
}
shift || true

date_arg="$(date +%F)"
agent_arg="all"
limit_arg=40
top_arg=12
show_lines=40

day_start_epoch() {
  local day="$1"
  date -j -f "%Y-%m-%d %H:%M:%S" "$day 00:00:00" "+%s" 2>/dev/null || date -d "$day 00:00:00" "+%s"
}

day_end_epoch() {
  local day="$1"
  date -j -v+1d -f "%Y-%m-%d %H:%M:%S" "$day 00:00:00" "+%s" 2>/dev/null || date -d "$day 00:00:00 + 1 day" "+%s"
}

mtime_epoch() {
  stat -c "%Y" "$1" 2>/dev/null || stat -f "%m" "$1"
}

mtime_human() {
  stat -c "%y" "$1" 2>/dev/null | cut -d. -f1 || stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$1"
}

file_size() {
  stat -c "%s" "$1" 2>/dev/null || stat -f "%z" "$1"
}

agent_for_path() {
  case "$1" in
    "$HOME/.codex/sessions/"*) echo "codex" ;;
    "$HOME/.claude/projects/"*) echo "claude" ;;
    "$HOME/.pi/agent/sessions/"*) echo "pi" ;;
    "$HOME/.cursor/projects/"*) echo "cursor" ;;
    *) echo "unknown" ;;
  esac
}

find_sessions() {
  {
    [ -d "$HOME/.codex/sessions" ] && find "$HOME/.codex/sessions" -type f -name "*.jsonl" ! -name "*.langfuse"
    [ -d "$HOME/.claude/projects" ] && find "$HOME/.claude/projects" -type f -name "*.jsonl"
    [ -d "$HOME/.pi/agent/sessions" ] && find "$HOME/.pi/agent/sessions" -type f -name "*.jsonl"
    [ -d "$HOME/.cursor/projects" ] && find "$HOME/.cursor/projects" -path "*/agent-transcripts/*.jsonl" -type f
  } 2>/dev/null
}

print_table_header() {
  echo "| agent | modified | lines | size | file |"
  echo "| --- | --- | ---: | ---: | --- |"
}

list_sessions() {
  local start end count
  start="$(day_start_epoch "$date_arg")"
  end="$(day_end_epoch "$date_arg")"
  count=0

  print_table_header
  while IFS= read -r file; do
    local agent mtime lines size
    agent="$(agent_for_path "$file")"
    [ "$agent_arg" = "all" ] || [ "$agent_arg" = "$agent" ] || continue
    mtime="$(mtime_epoch "$file")"
    [ "$mtime" -ge "$start" ] && [ "$mtime" -lt "$end" ] || continue
    lines="$(wc -l < "$file" | tr -d ' ')"
    size="$(file_size "$file")"
    printf '| %s | %s | %s | %s | `%s` |\n' "$agent" "$(mtime_human "$file")" "$lines" "$size" "$file"
    count=$((count + 1))
    [ "$count" -lt "$limit_arg" ] || break
  done < <(find_sessions | while IFS= read -r f; do printf '%s\t%s\n' "$(mtime_epoch "$f")" "$f"; done | sort -rn | cut -f2-)
}

top_sessions() {
  local start end count
  start="$(day_start_epoch "$date_arg")"
  end="$(day_end_epoch "$date_arg")"
  count=0

  print_table_header
  while IFS=$'\t' read -r lines file; do
    local agent mtime size
    agent="$(agent_for_path "$file")"
    [ "$agent_arg" = "all" ] || [ "$agent_arg" = "$agent" ] || continue
    mtime="$(mtime_epoch "$file")"
    [ "$mtime" -ge "$start" ] && [ "$mtime" -lt "$end" ] || continue
    size="$(file_size "$file")"
    printf '| %s | %s | %s | %s | `%s` |\n' "$agent" "$(mtime_human "$file")" "$lines" "$size" "$file"
    count=$((count + 1))
    [ "$count" -lt "$top_arg" ] || break
  done < <(find_sessions | while IFS= read -r f; do printf '%s\t%s\n' "$(wc -l < "$f" | tr -d ' ')" "$f"; done | sort -rn)
}

show_session() {
  local file="$1"
  [ -f "$file" ] || {
    echo "session file not found: $file" >&2
    exit 1
  }

  echo "## Session"
  echo "- agent: $(agent_for_path "$file")"
  echo "- file: $file"
  echo "- modified: $(mtime_human "$file")"
  echo "- lines: $(wc -l < "$file" | tr -d ' ')"
  echo "- size: $(file_size "$file")"
  echo

  echo "## First records"
  head -n "$show_lines" "$file" | jq -r '
    def text:
      if (.message? | type) == "array" then
        (.message | map(select((.type? // "") == "text") | .text? // empty) | join(" "))
      elif (.content? | type) == "array" then
        (.content | map(select((.type? // "") == "text") | .text? // empty) | join(" "))
      elif (.message.content? | type) == "array" then
        (.message.content | map(select((.type? // "") == "text") | .text? // empty) | join(" "))
      else
        .message.content? // .message? // .content? // .payload.message? // .payload.input? // .payload.output? // .text? // empty
      end;
    select((.type? // .role? // "") | test("user|assistant|message|response|turn|item|summary"; "i"))
    | "- " + ((.timestamp? // .payload.timestamp? // "") | tostring) + " " + ((.type? // .role? // "") | tostring) + ": " + ((text | tostring) | gsub("\n"; " ") | .[0:500])
  ' 2>/dev/null || head -n "$show_lines" "$file"
  echo

  echo "## Last records"
  tail -n "$show_lines" "$file" | jq -r '
    def text:
      if (.message? | type) == "array" then
        (.message | map(select((.type? // "") == "text") | .text? // empty) | join(" "))
      elif (.content? | type) == "array" then
        (.content | map(select((.type? // "") == "text") | .text? // empty) | join(" "))
      elif (.message.content? | type) == "array" then
        (.message.content | map(select((.type? // "") == "text") | .text? // empty) | join(" "))
      else
        .message.content? // .message? // .content? // .payload.message? // .payload.input? // .payload.output? // .text? // empty
      end;
    select((.type? // .role? // "") | test("user|assistant|message|response|turn|item|summary|error"; "i"))
    | "- " + ((.timestamp? // .payload.timestamp? // "") | tostring) + " " + ((.type? // .role? // "") | tostring) + ": " + ((text | tostring) | gsub("\n"; " ") | .[0:500])
  ' 2>/dev/null || tail -n "$show_lines" "$file"
}

parse_common_options() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --date) date_arg="${2:?}"; shift 2 ;;
      --agent) agent_arg="${2:?}"; shift 2 ;;
      --limit) limit_arg="${2:?}"; shift 2 ;;
      --top) top_arg="${2:?}"; shift 2 ;;
      --lines) show_lines="${2:?}"; shift 2 ;;
      -h|--help) usage; exit 0 ;;
      *) echo "unknown option: $1" >&2; usage; exit 1 ;;
    esac
  done
}

case "$command" in
  list)
    parse_common_options "$@"
    list_sessions
    ;;
  retro)
    parse_common_options "$@"
    echo "## Sessions updated on $date_arg"
    list_sessions
    echo
    echo "## Largest sessions"
    top_sessions
    ;;
  show)
    session_file="${1:-}"
    [ -n "$session_file" ] || {
      echo "session-file is required" >&2
      usage
      exit 1
    }
    shift
    parse_common_options "$@"
    show_session "$session_file"
    ;;
  -h|--help)
    usage
    ;;
  *)
    echo "unknown command: $command" >&2
    usage
    exit 1
    ;;
esac
