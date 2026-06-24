#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  langfuse-traces.sh list [options]
  langfuse-traces.sh get <trace-id> [options]
  langfuse-traces.sh retro [options]

Environment:
  LANGFUSE_BASE_URL    Base URL of Langfuse (default: http://localhost:3000)
  LANGFUSE_PUBLIC_KEY  Langfuse public key for Basic Auth
  LANGFUSE_SECRET_KEY  Langfuse secret key for Basic Auth
  LANGFUSE_CONFIG_FILE JSON config file path (default: ~/.codex/langfuse.json when present)

Commands:
  list                 List traces in a compact Markdown format
  get                  Fetch a single trace and print JSON
  retro                Print today's list and top traces for review

Options for list:
  --today              Use today's local time range
  --from ISO8601       Start timestamp
  --to ISO8601         End timestamp
  --limit N            Number of traces to fetch (default: 20)
  --page N             Page number (default: 1)
  --name VALUE         Filter by trace name
  --user-id VALUE      Filter by user ID
  --session-id VALUE   Filter by session ID
  --tag VALUE          Filter by tag, repeatable
  --environment VALUE  Filter by environment, repeatable
  --order-by VALUE     Sort order (default: timestamp.desc)
  --fields VALUE       Field groups (default: omitted)

Options for get:
  --fields VALUE       Field groups (default: omitted)

Options for retro:
  --today              Use today's local time range (default: true)
  --limit N            Number of traces to inspect (default: 20)
  --top N              Number of top traces to expand (default: 3)
  --sort-by FIELD      latency|cost (default: latency)
  --name VALUE         Filter by trace name
  --user-id VALUE      Filter by user ID
  --session-id VALUE   Filter by session ID
  --tag VALUE          Filter by tag, repeatable
  --environment VALUE  Filter by environment, repeatable
EOF
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing command: $1" >&2
    exit 1
  fi
}

require_env() {
  local name="$1"
  if [ -z "${!name:-}" ]; then
    echo "missing environment variable: $name" >&2
    exit 1
  fi
}

load_langfuse_config() {
  local config_file="${LANGFUSE_CONFIG_FILE:-$HOME/.codex/langfuse.json}"
  [ -f "$config_file" ] || return 0

  require_command jq

  if [ -z "${LANGFUSE_BASE_URL:-}" ]; then
    LANGFUSE_BASE_URL="$(jq -r '.base_url // empty' "$config_file")"
  fi
  if [ -z "${LANGFUSE_PUBLIC_KEY:-}" ]; then
    LANGFUSE_PUBLIC_KEY="$(jq -r '.public_key // empty' "$config_file")"
  fi
  if [ -z "${LANGFUSE_SECRET_KEY:-}" ]; then
    LANGFUSE_SECRET_KEY="$(jq -r '.secret_key // empty' "$config_file")"
  fi
}

urlencode() {
  jq -rn --arg v "$1" '$v|@uri'
}

append_query() {
  local key="$1"
  local value="$2"
  if [ -n "$query" ]; then
    query="${query}&"
  fi
  query="${query}${key}=$(urlencode "$value")"
}

iso_day_start() {
  python3 - <<'PY'
from datetime import datetime
now = datetime.now().astimezone()
start = now.replace(hour=0, minute=0, second=0, microsecond=0)
print(start.isoformat())
PY
}

iso_next_day_start() {
  python3 - <<'PY'
from datetime import datetime, timedelta
now = datetime.now().astimezone()
tomorrow = now.replace(hour=0, minute=0, second=0, microsecond=0) + timedelta(days=1)
print(tomorrow.isoformat())
PY
}

fetch() {
  local path="$1"
  curl -fsSL -u "${LANGFUSE_PUBLIC_KEY}:${LANGFUSE_SECRET_KEY}" \
    "${LANGFUSE_BASE_URL%/}${path}"
}

format_list() {
  jq -r '
    def fmt(v): if v == null or v == "" then "-" else (v|tostring) end;
    def tags(v): if (v|type) == "array" and (v|length) > 0 then (v|join(",")) else "-" end;
    [
      "| traceId | timestamp | name | userId | sessionId | latency(s) | totalTokens | cost(USD) | observations | tags |",
      "| --- | --- | --- | --- | --- | ---: | ---: | ---: | ---: | --- |"
    ] +
    (
      (.data // []) | map(
        "| \(fmt(.id)) | \(fmt(.timestamp)) | \(fmt(.name)) | \(fmt(.userId)) | \(fmt(.sessionId)) | \(fmt(.latency)) | \(fmt(.totalTokens // .tokens)) | \(fmt(.totalCost)) | \(if (.observations|type) == "array" then (.observations|length) else 0 end) | \(tags(.tags)) |"
      )
    )
    | join("\n")
  '
}

list_json() {
  fetch "/api/public/traces?${query}"
}

format_retro() {
  local top="${1}"
  local sort_by="${2}"
  jq -r --argjson top "$top" --arg sort_by "$sort_by" '
    def fmt(v): if v == null or v == "" then "-" else (v|tostring) end;
    def tags(v): if (v|type) == "array" and (v|length) > 0 then (v|join(",")) else "-" end;
    def textish(v):
      if v == null then ""
      elif (v|type) == "string" then v
      elif (v|type) == "object" or (v|type) == "array" then (v|tojson)
      else (v|tostring)
      end;
    def compact_text(v):
      (textish(v) | gsub("[[:space:]]+"; " ") | sub("^ "; "") | sub(" $"; ""));
    def snippet(v):
      (compact_text(v)) as $t
      | if $t == "" then "-"
        elif ($t|length) > 180 then ($t[0:180] + "...")
        else $t
        end;
    def work_type:
      ((textish(.input) + "\n" + textish(.output) + "\n" + textish(.name)) | ascii_downcase) as $t
      | if ($t | test("review|pr review|code review")) then "review"
        elif ($t | test("refactor|rename")) then "refactor"
        elif ($t | test("debug|diagnose|investigate|trace|log")) then "investigate"
        elif ($t | test("pytest|jest|go test|test")) then "test"
        elif ($t | test("readme|document|docs|confluence|jira|plan\\.md")) then "docs"
        elif ($t | test("search|look up|grep|rg ")) then "search"
        else "implement"
        end;
    def metric:
      if $sort_by == "cost" then (.totalCost // 0)
      else (.latency // 0)
      end;
    def observations_count:
      if (.observations|type) == "array" then (.observations|length) else 0 end;
    "## Today traces\n"
    + (
      [
        "| traceId | timestamp | name | workType | sessionId | latency(s) | cost(USD) | observations | tags |",
        "| --- | --- | --- | --- | --- | ---: | ---: | ---: | --- |"
      ]
      + (
        (.data // []) | map(
          "| \(fmt(.id)) | \(fmt(.timestamp)) | \(fmt(.name)) | \(work_type) | \(fmt(.sessionId)) | \(fmt(.latency)) | \(fmt(.totalCost)) | \(observations_count) | \(tags(.tags)) |"
        )
      )
    | join("\n"))
    + "\n\n## Top traces\n"
    + (
      ((.data // []) | sort_by(metric) | reverse | .[:$top]) as $toptraces
      | if ($toptraces|length) == 0 then
          "- no traces found"
        else
          ($toptraces | to_entries | map(
            "### \(.key + 1). \(fmt(.value.name))\n"
            + "- traceId: `\(fmt(.value.id))`\n"
            + "- timestamp: `\(fmt(.value.timestamp))`\n"
            + "- workType: `\(.value | work_type)`\n"
            + "- sessionId: `\(fmt(.value.sessionId))`\n"
            + "- latency(s): `\(fmt(.value.latency))`\n"
            + "- cost(USD): `\(fmt(.value.totalCost))`\n"
            + "- observations: `\(if (.value.observations|type) == "array" then (.value.observations|length) else 0 end)`\n"
            + "- tags: `\(tags(.value.tags))`\n"
            + "- input: `\(snippet(.value.input))`\n"
            + "- output: `\(snippet(.value.output))`"
          ) | join("\n\n"))
        end
    )
  '
}

command="${1:-}"
[ -n "$command" ] || {
  usage
  exit 1
}
shift

require_command curl
require_command jq
load_langfuse_config

case "$command" in
  -h|--help|help)
    usage
    exit 0
    ;;
  list)
    LANGFUSE_BASE_URL="${LANGFUSE_BASE_URL:-http://localhost:3000}"
    require_env LANGFUSE_PUBLIC_KEY
    require_env LANGFUSE_SECRET_KEY
    limit="20"
    page="1"
    name=""
    user_id=""
    session_id=""
    order_by="timestamp.desc"
    fields=""
    from_ts=""
    to_ts=""
    today="false"
    tags=()
    environments=()

    while [ "$#" -gt 0 ]; do
      case "$1" in
        --today) today="true" ;;
        --from) from_ts="${2:?}"; shift ;;
        --to) to_ts="${2:?}"; shift ;;
        --limit) limit="${2:?}"; shift ;;
        --page) page="${2:?}"; shift ;;
        --name) name="${2:?}"; shift ;;
        --user-id) user_id="${2:?}"; shift ;;
        --session-id) session_id="${2:?}"; shift ;;
        --tag) tags+=("${2:?}"); shift ;;
        --environment) environments+=("${2:?}"); shift ;;
        --order-by) order_by="${2:?}"; shift ;;
        --fields) fields="${2:?}"; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown option for list: $1" >&2; usage; exit 1 ;;
      esac
      shift
    done

    if [ "$today" = "true" ]; then
      from_ts="$(iso_day_start)"
      to_ts="$(iso_next_day_start)"
    fi

    query=""
    append_query page "$page"
    append_query limit "$limit"
    append_query orderBy "$order_by"
    [ -n "$fields" ] && append_query fields "$fields"
    [ -n "$name" ] && append_query name "$name"
    [ -n "$user_id" ] && append_query userId "$user_id"
    [ -n "$session_id" ] && append_query sessionId "$session_id"
    [ -n "$from_ts" ] && append_query fromTimestamp "$from_ts"
    [ -n "$to_ts" ] && append_query toTimestamp "$to_ts"
    if [ "${#tags[@]}" -gt 0 ]; then
      for tag in "${tags[@]}"; do
        append_query tags "$tag"
      done
    fi
    if [ "${#environments[@]}" -gt 0 ]; then
      for environment in "${environments[@]}"; do
        append_query environment "$environment"
      done
    fi

    fetch "/api/public/traces?${query}" | format_list
    ;;
  get)
    LANGFUSE_BASE_URL="${LANGFUSE_BASE_URL:-http://localhost:3000}"
    require_env LANGFUSE_PUBLIC_KEY
    require_env LANGFUSE_SECRET_KEY
    trace_id="${1:-}"
    [ -n "$trace_id" ] || {
      echo "trace-id is required" >&2
      usage
      exit 1
    }
    shift
    fields=""

    while [ "$#" -gt 0 ]; do
      case "$1" in
        --fields) fields="${2:?}"; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown option for get: $1" >&2; usage; exit 1 ;;
      esac
      shift
    done

    path="/api/public/traces/${trace_id}"
    if [ -n "$fields" ]; then
      path="${path}?fields=$(urlencode "$fields")"
    fi
    fetch "$path" | jq .
    ;;
  retro)
    require_env LANGFUSE_PUBLIC_KEY
    require_env LANGFUSE_SECRET_KEY
    LANGFUSE_BASE_URL="${LANGFUSE_BASE_URL:-http://localhost:3000}"
    limit="20"
    top="3"
    name=""
    user_id=""
    session_id=""
    fields=""
    from_ts=""
    to_ts=""
    today="true"
    tags=()
    environments=()
    sort_by="latency"

    while [ "$#" -gt 0 ]; do
      case "$1" in
        --today) today="true" ;;
        --from) from_ts="${2:?}"; shift ;;
        --to) to_ts="${2:?}"; shift ;;
        --limit) limit="${2:?}"; shift ;;
        --top) top="${2:?}"; shift ;;
        --sort-by) sort_by="${2:?}"; shift ;;
        --name) name="${2:?}"; shift ;;
        --user-id) user_id="${2:?}"; shift ;;
        --session-id) session_id="${2:?}"; shift ;;
        --tag) tags+=("${2:?}"); shift ;;
        --environment) environments+=("${2:?}"); shift ;;
        --fields) fields="${2:?}"; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown option for retro: $1" >&2; usage; exit 1 ;;
      esac
      shift
    done

    if [ "$sort_by" != "latency" ] && [ "$sort_by" != "cost" ]; then
      echo "sort-by must be latency or cost" >&2
      exit 1
    fi

    if [ "$today" = "true" ]; then
      from_ts="$(iso_day_start)"
      to_ts="$(iso_next_day_start)"
    fi

    query=""
    append_query page "1"
    append_query limit "$limit"
    [ -n "$name" ] && append_query name "$name"
    [ -n "$user_id" ] && append_query userId "$user_id"
    [ -n "$session_id" ] && append_query sessionId "$session_id"
    [ -n "$fields" ] && append_query fields "$fields"
    [ -n "$from_ts" ] && append_query fromTimestamp "$from_ts"
    [ -n "$to_ts" ] && append_query toTimestamp "$to_ts"
    if [ "${#tags[@]}" -gt 0 ]; then
      for tag in "${tags[@]}"; do
        append_query tags "$tag"
      done
    fi
    if [ "${#environments[@]}" -gt 0 ]; then
      for environment in "${environments[@]}"; do
        append_query environment "$environment"
      done
    fi

    list_json | format_retro "$top" "$sort_by"
    ;;
  *)
    echo "unknown command: $command" >&2
    usage
    exit 1
    ;;
esac
