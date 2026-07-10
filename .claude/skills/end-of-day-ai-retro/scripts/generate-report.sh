#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SANITIZE_CHECK="$SCRIPT_DIR/sanitize-check.sh"
target_date="$(date +%F)"
time_zone="${AI_RETRO_TIME_ZONE:-${TZ:-Etc/UTC}}"
output_root=""
dry_run=false

usage() {
  cat <<'USAGE'
Usage: generate-report.sh [--date YYYY-MM-DD] [--time-zone ZONE] [--output-root DIR] [--dry-run]

Creates DIR/YYYY-MM-DD/{report.md,run-summary.edn,missing-sources.tsv,input-inventory.tsv}.
The same target date replaces the previous artifact instead of appending proposals.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --date) target_date="${2:?--date requires YYYY-MM-DD}"; shift 2 ;;
    --time-zone) time_zone="${2:?--time-zone requires an IANA zone}"; shift 2 ;;
    --output-root) output_root="${2:?--output-root requires DIR}"; shift 2 ;;
    --dry-run) dry_run=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
done

zoneinfo_path=""
for zoneinfo_root in "${TZDIR:-}" /usr/share/zoneinfo /usr/share/lib/zoneinfo /etc/zoneinfo; do
  [ -n "$zoneinfo_root" ] || continue
  if [[ "$time_zone" != /* && "$time_zone" != *..* && -f "$zoneinfo_root/$time_zone" ]]; then
    zoneinfo_path="$zoneinfo_root/$time_zone"
    break
  fi
done
[ -n "$zoneinfo_path" ] || { echo "Invalid IANA time zone: $time_zone" >&2; exit 1; }

normalized_date="$(TZ="$time_zone" date -d "$target_date" +%F 2>/dev/null || TZ="$time_zone" date -j -f '%Y-%m-%d' "$target_date" +%F 2>/dev/null || true)"
[ "$normalized_date" = "$target_date" ] || { echo "Invalid date: $target_date" >&2; exit 1; }

if [ "$dry_run" = false ] && [ -z "$output_root" ]; then
  echo "--output-root is required unless --dry-run is used" >&2
  exit 1
fi

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT
artifact="$work_dir/$target_date"
mkdir -p "$artifact"
inventory="$artifact/input-inventory.tsv"
missing="$artifact/missing-sources.tsv"
failure_category_log="$work_dir/failure-categories.tsv"
printf 'source\tidentifier\tstatus\n' > "$inventory"
printf 'source\treason\n' > "$missing"
: > "$failure_category_log"

day_start_epoch() {
  TZ="$time_zone" date -j -f '%Y-%m-%d %H:%M:%S' "$1 00:00:00" '+%s' 2>/dev/null || TZ="$time_zone" date -d "$1 00:00:00" '+%s'
}
day_end_epoch() {
  local next_day
  next_day="$(TZ="$time_zone" date -j -v+1d -f '%Y-%m-%d' "$1" '+%F' 2>/dev/null || \
    TZ="$time_zone" date -d "$1 tomorrow" '+%F')"
  day_start_epoch "$next_day"
}
mtime_epoch() { stat -c '%Y' "$1" 2>/dev/null || stat -f '%m' "$1"; }
identifier_for_file() {
  local source="$1" file="$2" digest
  digest="$(printf '%s' "$file" | { sha256sum 2>/dev/null || shasum -a 256; } | awk '{print substr($1,1,12)}')"
  printf '%s:%s' "$source" "$digest"
}
identifier_for_value() {
  local source="$1" value="$2" digest
  digest="$(printf '%s' "$value" | { sha256sum 2>/dev/null || shasum -a 256; } | awk '{print substr($1,1,12)}')"
  printf '%s:%s' "$source" "$digest"
}
timestamp_epoch() {
  local value="$1"
  if [[ "$value" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    awk -v value="$value" 'BEGIN {
      # Session writers use both Unix seconds and Unix milliseconds.
      if (value >= 100000000000) value = value / 1000
      printf "%.0f\n", int(value)
    }'
  else
    [[ "$value" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?(Z|[+-][0-9]{2}:?[0-9]{2})$ ]] || return 1
    if [[ "$value" =~ ([+-])([0-9]{2}):?([0-9]{2})$ ]]; then
      local offset_hours="${BASH_REMATCH[2]}" offset_minutes="${BASH_REMATCH[3]}"
      if (( 10#$offset_hours > 14 || 10#$offset_minutes > 59 ||
            (10#$offset_hours == 14 && 10#$offset_minutes != 0) )); then
        return 1
      fi
    fi
    date -d "$value" '+%s' 2>/dev/null || {
      local normalized="$value"
      normalized="$(printf '%s\n' "$normalized" | sed -E \
        -e 's/\.[0-9]+(Z|[+-][0-9]{2}:?[0-9]{2})$/\1/' \
        -e 's/Z$/+0000/' \
        -e 's/([+-][0-9]{2}):([0-9]{2})$/\1\2/')"
      date -j -f '%Y-%m-%dT%H:%M:%S%z' "$normalized" '+%s' 2>/dev/null
    }
  fi
}

classify_jsonl_for_period() {
  local file="$1" destination="$2"
  # jq's mktime/strftime use the process timezone. ISO timestamps represent an
  # absolute instant, so keep their calendar conversion independent of the host.
  TZ=UTC jq -c --argjson start "$start" --argjson end "$end" '
    def timestamp_fields:
      [
        (if has("timestamp") then .timestamp else empty end),
        (if ((.payload? | type) == "object" and (.payload | has("timestamp"))) then .payload.timestamp else empty end),
        (if ((.message? | type) == "object" and (.message | has("timestamp"))) then .message.timestamp else empty end),
        (if has("created_at") then .created_at else empty end),
        (if has("createdAt") then .createdAt else empty end),
        (if has("startTime") then .startTime else empty end),
        (if has("time") then .time else empty end)
      ];
    def timestamp_epoch:
      if type == "number" then (if . >= 100000000000 then . / 1000 else . end | floor)
      elif type == "string" and test("^[0-9]+(?:\\.[0-9]+)?$") then
        (tonumber | if . >= 100000000000 then . / 1000 else . end | floor)
      elif type == "string" and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(?:\\.[0-9]+)?(?:Z|[+-][0-9]{2}:?[0-9]{2})$") then
        try (
          capture("^(?<base>[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2})(?:\\.[0-9]+)?(?<zone>Z|[+-][0-9]{2}:?[0-9]{2})$") as $parts |
          ($parts.base | strptime("%Y-%m-%dT%H:%M:%S") | mktime) as $local_epoch |
          if ($local_epoch | strftime("%Y-%m-%dT%H:%M:%S")) != $parts.base then null
          elif $parts.zone == "Z" then $local_epoch
          else
            ($parts.zone | capture("^(?<sign>[+-])(?<hours>[0-9]{2}):?(?<minutes>[0-9]{2})$")) as $zone |
            ($zone.hours | tonumber) as $hours |
            ($zone.minutes | tonumber) as $minutes |
            if $hours > 14 or $minutes > 59 or ($hours == 14 and $minutes != 0) then null
            else $local_epoch - (($hours * 3600 + $minutes * 60) *
              (if $zone.sign == "+" then 1 else -1 end))
            end
          end
        ) catch null
      else null
      end;
    select(type == "object") as $record |
    timestamp_fields as $timestamps |
    if ($timestamps | length) == 0 then {kind: "absent"}
    else ([$timestamps[] | timestamp_epoch | select(. != null)] | .[0] // null) as $epoch |
      if $epoch == null then {kind: "invalid"}
      elif $epoch >= $start and $epoch < $end then {kind: "selected", record: $record}
      else {kind: "outside"}
      end
    end
  ' "$file" > "$destination"
}

start="$(day_start_epoch "$target_date")"
end="$(day_end_epoch "$target_date")"
codex_count=0
claude_count=0
pi_count=0
cursor_count=0
task_board_count=0
langfuse_count=0
invalid_json=0
failure_files=0
success_files=0
token_total=0
duration_ms_total=0
metric_files=0
evidence_ids=()

increment_count() {
  case "$1" in
    codex) codex_count=$((codex_count + 1)) ;;
    claude) claude_count=$((claude_count + 1)) ;;
    pi) pi_count=$((pi_count + 1)) ;;
    cursor) cursor_count=$((cursor_count + 1)) ;;
  esac
}

failure_categories_for_file() {
  local file="$1" kind exit_code cause normalized digest category
  while IFS=$'\t' read -r kind exit_code cause; do
    [ -n "$kind" ] || continue
    normalized="$(normalize_failure_text "$cause")"
    digest="$(printf '%s' "$normalized" | { sha256sum 2>/dev/null || shasum -a 256; } | awk '{print substr($1,1,12)}')"

    # Order matters: choose one remediation-oriented cause before considering
    # broad families such as permission, timeout, or nonzero exit.
    if [[ "$normalized" =~ (missing|required|not[[:space:]]+(set|found|provided)).*(credential|api[[:space:]_-]*key|auth[[:space:]_-]*token) ]] ||
       [[ "$normalized" =~ (credential|api[[:space:]_-]*key|auth[[:space:]_-]*token).*(missing|required|not[[:space:]]+(set|found|provided)) ]]; then
      category="authentication:missing-credential:signature-$digest"
    elif [[ "$normalized" =~ (invalid|expired|revoked).*(credential|api[[:space:]_-]*key|auth[[:space:]_-]*token) ]] ||
         [[ "$normalized" =~ (credential|api[[:space:]_-]*key|auth[[:space:]_-]*token).*(invalid|expired|revoked) ]]; then
      category="authentication:invalid-credential:signature-$digest"
    elif [[ "$normalized" =~ unauthorized|unauthenticated|authentication[[:space:]_-]*failed|http[^0-9]*401 ]]; then
      category="authentication:unauthorized:signature-$digest"
    elif [[ "$normalized" =~ quota ]]; then
      category="rate-limit:quota:signature-$digest"
    elif [[ "$normalized" =~ rate[[:space:]_-]*limit|too[[:space:]]+many[[:space:]]+requests|http[^0-9]*429 ]]; then
      category="rate-limit:requests:signature-$digest"
    elif [[ "$normalized" =~ sandbox|approval[[:space:]_-]*(required|denied)|denied[[:space:]]+by[[:space:]]+policy ]]; then
      category="permission:sandbox:signature-$digest"
    elif [[ "$normalized" =~ permission[[:space:]]+denied|access[[:space:]]+denied|operation[[:space:]]+not[[:space:]]+permitted|read-only[[:space:]]+file[[:space:]]+system ]]; then
      category="permission:filesystem:signature-$digest"
    elif [[ "$normalized" =~ forbidden|http[^0-9]*403 ]]; then
      category="permission:forbidden:signature-$digest"
    elif [[ "$normalized" =~ deadline[[:space:]_-]*exceeded ]]; then
      category="timeout:deadline:signature-$digest"
    elif [[ "$normalized" =~ (timeout|timed[[:space:]]+out).*(connection|network|dns|host) ]] ||
         [[ "$normalized" =~ (connection|network|dns|host).*(timeout|timed[[:space:]]+out) ]]; then
      category="timeout:network:signature-$digest"
    elif [[ "$normalized" =~ timeout|timed[[:space:]]+out ]]; then
      category="timeout:operation:signature-$digest"
    elif [[ "$normalized" =~ dns|name[[:space:]]+resolution|resolve[[:space:]]+host ]]; then
      category="network:dns:signature-$digest"
    elif [[ "$normalized" =~ connection[[:space:]_-]*refused ]]; then
      category="network:connection-refused:signature-$digest"
    elif [[ "$normalized" =~ tls|ssl|certificate[[:space:]_-]*(verify|verification|expired|invalid|error|failed) ]]; then
      category="network:tls:signature-$digest"
    elif [[ "$normalized" =~ host[[:space:]_-]*unreachable|no[[:space:]]+route[[:space:]]+to[[:space:]]+host ]]; then
      category="network:host-unreachable:signature-$digest"
    elif [[ "$normalized" =~ connection[[:space:]_-]*(reset|failed|error)|network[[:space:]_-]*unreachable ]]; then
      category="network:connection:signature-$digest"
    elif [[ "$normalized" =~ module[[:space:]]+not[[:space:]]+found|cannot[[:space:]]+find[[:space:]]+module|missing[[:space:]_-]*dependency|package.*not[[:space:]]+found ]]; then
      category="dependency:missing:signature-$digest"
    elif [[ "$normalized" =~ command[[:space:]]+not[[:space:]]+found|executable[[:space:]]+file.*not[[:space:]]+found|no[[:space:]]+such[[:space:]]+command ]]; then
      category="not-found:command:signature-$digest"
    elif [[ "$normalized" =~ no[[:space:]]+such[[:space:]]+(file|directory)|file[[:space:]]+not[[:space:]]+found ]]; then
      category="not-found:file:signature-$digest"
    elif [[ "$normalized" =~ http[^0-9]*404 ]]; then
      category="not-found:http-resource:signature-$digest"
    elif [[ "$normalized" =~ not[[:space:]_-]+found ]]; then
      category="not-found:resource:signature-$digest"
    else
      if [ "$kind" = nonzero ]; then
        category="nonzero-exit:code-${exit_code}:signature-$digest"
      else
        category="unknown:signature-$digest"
      fi
    fi
    printf '%s\n' "$category"
  done < <(jq -scr '
    def embedded_exit_code:
      ((.payload.output? // .output? // "") | tostring) as $output |
      (try ($output | capture("\\\"exit_code\\\"[[:space:]]*:[[:space:]]*\\\"?(?<code>[1-9][0-9]*)\\\"?[[:space:]]*[,}]").code) catch null) // null;
    def positive_exit_code:
      if type == "number" and . > 0 and . == floor then tostring
      elif type == "string" and test("^[1-9][0-9]*$") then (tonumber | tostring)
      else null
      end;
    def is_tool_output_type:
      type == "string" and test("(^|_)(tool|function)[a-z0-9_-]*output($|_)");
    def is_tool_output_record:
      ((.type? // "") | is_tool_output_type) or
      ((.payload.type? // "") | is_tool_output_type);
    def nonzero_exit_code:
      if is_tool_output_record then
        (.exit_code? | positive_exit_code) //
        (.payload.exit_code? | positive_exit_code) //
        embedded_exit_code
      else null
      end;
    def message_content:
      .message? |
      select(type == "object") |
      .content? |
      select(type == "array") |
      .[];
    def failed_tool_result:
      message_content |
      select(.type? == "tool_result" and .is_error? == true);
    def message_cause_fields:
      .error?, .content?, .text?, .output?, .stderr?, .reason?, .detail?, .details?;
    def object_message_cause:
      (.message? | select(type == "object") | message_cause_fields),
      (.payload.message? | select(type == "object") | message_cause_fields);
    def cause_text:
      . as $record |
      [
        .error?,
        (if (.message? | type) == "string" then .message else empty end),
        .content?, .output?, .stderr?, .reason?, .detail?, .details?,
        .payload.error?,
        (if (.payload.message? | type) == "string" then .payload.message else empty end),
        .payload.content?, .payload.output?, .payload.stderr?, .payload.reason?, .payload.detail?, .payload.details?,
        object_message_cause,
        (failed_tool_result |
          (.content? // .text? // .output? // .message? // empty))
      ] |
      map(select(. != null) | if type == "string" then . else tojson end) |
      if length > 0 then join(" ")
      else "record-type=" + (($record.type? // $record.payload.type? // "unknown") | tostring) +
        " status=" + (($record.status? // $record.payload.status? // "unknown") | tostring)
      end;
    .[] |
    nonzero_exit_code as $exit_code |
    select(
      (.type? == "error") or (.payload.type? == "error") or
      (.status? == "failed") or (.payload.status? == "failed") or
      (.is_error? == true) or (.payload.is_error? == true) or
      any(failed_tool_result; true) or
      ($exit_code != null)) |
    [(if $exit_code != null then "nonzero" else "structured" end), ($exit_code // "-"), cause_text] |
    @tsv
  ' "$file" | sort -u)
}

normalize_failure_text() {
  local value="$1"
  printf '%s' "$value" |
    tr '[:upper:]' '[:lower:]' |
    sed -E \
      -e 's/[0-9]{4}-[0-9]{2}-[0-9]{2}t[0-9]{2}:[0-9]{2}:[0-9]{2}([.][0-9]+)?(z|[+-][0-9]{2}:?[0-9]{2})/<timestamp>/g' \
      -e 's/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/<uuid>/g' \
      -e "s/(request|record|session|trace|task|run|call)[_ -]?id[\"']?[[:space:]]*[=:][[:space:]]*[\"']?[-a-z0-9_.]{6,}/\1_id=<id>/g" \
      -e "s#/var/folders/[^[:space:]\"']+#<tmp-path>#g" \
      -e "s#/tmp/[^[:space:]\"']+#<tmp-path>#g" \
      -e 's/0x[0-9a-f]+/<address>/g' \
      -e 's/[0-9a-f]{12,}/<hex-id>/g' \
      -e 's/[0-9]+([.][0-9]+)?[[:space:]]*(milliseconds?|ms|seconds?|secs?)/<duration>/g' \
      -e 's/[0-9]{6,}/<number>/g' \
      -e 's/[[:space:]]+/ /g' \
      -e 's/^ //; s/ $//'
}

add_sessions() {
  local source="$1" root="$2" glob_kind="${3:-all}"
  if [ ! -d "$root" ]; then
    printf '%s\t%s\n' "$source" "directory not found" >> "$missing"
    return
  fi
  local found=0 file mtime identifier status file_tokens file_duration file_failure_categories category
  local analysis_file classified_file filtered_file timestamp_records invalid_timestamps
  while IFS= read -r file; do
    identifier="$(identifier_for_file "$source" "$file")"
    status="ok"
    if ! jq -s empty "$file" >/dev/null 2>&1; then
      mtime="$(mtime_epoch "$file")"
      [ "$mtime" -ge "$start" ] && [ "$mtime" -lt "$end" ] || continue
      found=1
      increment_count "$source"
      status="invalid-jsonl"
      invalid_json=$((invalid_json + 1))
    else
      classified_file="$work_dir/session-$(printf '%s' "$identifier" | tr ':' '-').classified.jsonl"
      filtered_file="$work_dir/session-$(printf '%s' "$identifier" | tr ':' '-').jsonl"
      classify_jsonl_for_period "$file" "$classified_file"
      timestamp_records="$(jq -sr '[.[] | select(.kind != "absent")] | length' "$classified_file")"
      if [ "$timestamp_records" -gt 0 ]; then
        # Timestamped formats are filtered record-by-record. Missing or invalid
        # timestamps in such a file must not silently inherit the file mtime.
        invalid_timestamps="$(jq -sr '[.[] | select(.kind == "invalid")] | length' "$classified_file")"
        if [ "$invalid_timestamps" -gt 0 ]; then
          printf '%s\t%s has %s records with unparseable timestamps\n' \
            "$source" "$identifier" "$invalid_timestamps" >> "$missing"
          status="${status},invalid-timestamp"
        fi
        jq -c 'select(.kind == "selected") | .record' "$classified_file" > "$filtered_file"
        if [ ! -s "$filtered_file" ]; then
          if [ "$invalid_timestamps" -gt 0 ]; then
            printf '%s\t%s\tinvalid-timestamp\n' "$source" "$identifier" >> "$inventory"
          fi
          continue
        fi
        analysis_file="$filtered_file"
      else
        mtime="$(mtime_epoch "$file")"
        [ "$mtime" -ge "$start" ] && [ "$mtime" -lt "$end" ] || continue
        analysis_file="$file"
      fi

      found=1
      increment_count "$source"
      file_tokens="$(jq -sr '([.[] |
        .payload? | select(type == "object") |
        .info? | select(type == "object") |
        .total_token_usage? | select(type == "object") |
        .total_tokens? | select(type == "number")
      ] | max // 0) | floor' "$analysis_file")"
      file_duration="$(jq -sr '([.[] |
        .payload? | select(type == "object") |
        .duration_ms? | select(type == "number")
      ] | add // 0) | floor' "$analysis_file")"
      if [ "$file_tokens" -gt 0 ] || [ "$file_duration" -gt 0 ]; then
        metric_files=$((metric_files + 1))
        token_total=$((token_total + file_tokens))
        duration_ms_total=$((duration_ms_total + file_duration))
      fi
      file_failure_categories="$(failure_categories_for_file "$analysis_file" | sort -u)"
      if [ -n "$file_failure_categories" ]; then
        failure_files=$((failure_files + 1))
        status="${status},friction"
        while IFS= read -r category; do
          [ -n "$category" ] || continue
          printf '%s\t%s\n' "$category" "$identifier" >> "$failure_category_log"
        done <<< "$file_failure_categories"
      fi
      if jq -se 'any(.[];
        ((.type? == "task_complete") or (.payload.type? == "task_complete")) or
        ((.type? == "result") and (((.subtype? // "") == "success") or ((.status? // "") == "success")) and ((.is_error? // false) == false)) or
        ((.payload.type? == "result") and (((.payload.subtype? // "") == "success") or ((.payload.status? // "") == "success")) and ((.payload.is_error? // false) == false)))' "$analysis_file" >/dev/null 2>&1; then
        success_files=$((success_files + 1))
      fi
    fi
    evidence_ids+=("$identifier")
    printf '%s\t%s\t%s\n' "$source" "$identifier" "$status" >> "$inventory"
  done < <(if [ "$glob_kind" = cursor ]; then find "$root" -path '*/agent-transcripts/*.jsonl' -type f 2>/dev/null | sort; else find "$root" -type f -name '*.jsonl' ! -name '*.langfuse' 2>/dev/null | sort; fi)
  [ "$found" -eq 1 ] || printf '%s\t%s\n' "$source" "no files for target date" >> "$missing"
}

add_sessions codex "${AI_RETRO_CODEX_ROOT:-$HOME/.codex/sessions}"
add_sessions claude "${AI_RETRO_CLAUDE_ROOT:-$HOME/.claude/projects}"
add_sessions pi "${AI_RETRO_PI_ROOT:-$HOME/.pi/agent/sessions}"
add_sessions cursor "${AI_RETRO_CURSOR_ROOT:-$HOME/.cursor/projects}" cursor

task_board_root="${AI_RETRO_TASK_BOARD_ROOT:-$HOME/.codex-task-board/workspaces}"
compact_date="${target_date//-/}"
if [ -d "$task_board_root" ]; then
  while IFS= read -r run; do
    task_board_count=$((task_board_count + 1))
    identifier="ticket-run:$(basename "$(dirname "$run")")/$(basename "$run")"
    evidence_ids+=("$identifier")
    printf 'task-board\t%s\tok\n' "$identifier" >> "$inventory"
  done < <(find "$task_board_root" -mindepth 2 -maxdepth 2 -type d -name "${compact_date}T*" 2>/dev/null | sort)
  [ "$task_board_count" -gt 0 ] || printf 'task-board\tno runs for target date\n' >> "$missing"
else
  printf 'task-board\tdirectory not found\n' >> "$missing"
fi

langfuse_config="${LANGFUSE_CONFIG_FILE:-$HOME/.codex/langfuse.json}"
langfuse_adapter="${AI_RETRO_LANGFUSE_ADAPTER:-}"
if [ -z "$langfuse_adapter" ]; then
  for adapter_candidate in \
    "$SCRIPT_DIR/langfuse-adapter.sh" \
    "$HOME/.local/bin/end-of-day-ai-retro-langfuse-adapter"; do
    if [ -x "$adapter_candidate" ]; then
      langfuse_adapter="$adapter_candidate"
      break
    fi
  done
fi
if [ -z "$langfuse_adapter" ] && command -v end-of-day-ai-retro-langfuse-adapter >/dev/null 2>&1; then
  langfuse_adapter="$(command -v end-of-day-ai-retro-langfuse-adapter)"
fi

if [ -n "$langfuse_adapter" ] && [ -x "$langfuse_adapter" ]; then
  langfuse_output="$work_dir/langfuse.jsonl"
  if AI_RETRO_TARGET_DATE="$target_date" AI_RETRO_TIME_ZONE="$time_zone" \
    "$langfuse_adapter" --start-epoch "$start" --end-epoch "$end" > "$langfuse_output" 2>/dev/null; then
    langfuse_invalid=0
    while IFS= read -r trace; do
      [ -n "$trace" ] || continue
      if ! trace_fields="$(printf '%s\n' "$trace" | jq -er '[
          (.id // .traceId // .trace_id // empty | tostring),
          (.timestamp // .startTime // .createdAt // .created_at // empty | tostring)
        ] | select(length == 2 and all(.[]; length > 0)) | @tsv' 2>/dev/null)"; then
        langfuse_invalid=$((langfuse_invalid + 1))
        continue
      fi
      IFS=$'\t' read -r trace_id trace_timestamp <<< "$trace_fields"
      if ! trace_epoch="$(timestamp_epoch "$trace_timestamp")"; then
        langfuse_invalid=$((langfuse_invalid + 1))
        continue
      fi
      [ "$trace_epoch" -ge "$start" ] && [ "$trace_epoch" -lt "$end" ] || continue
      identifier="$(identifier_for_value langfuse "$trace_id")"
      langfuse_count=$((langfuse_count + 1))
      evidence_ids+=("$identifier")
      printf 'langfuse\t%s\tok\n' "$identifier" >> "$inventory"
    done < "$langfuse_output"
    [ "$langfuse_count" -gt 0 ] || printf 'langfuse\tadapter returned no traces for target date\n' >> "$missing"
    [ "$langfuse_invalid" -eq 0 ] || printf 'langfuse\tadapter returned %s invalid records\n' "$langfuse_invalid" >> "$missing"
  else
    printf 'langfuse\tadapter execution failed\n' >> "$missing"
  fi
elif [ -n "$langfuse_adapter" ]; then
  printf 'langfuse\tconfigured adapter is not executable\n' >> "$missing"
elif [ -f "$langfuse_config" ] || { [ -n "${LANGFUSE_PUBLIC_KEY:-}" ] && [ -n "${LANGFUSE_SECRET_KEY:-}" ]; }; then
  printf 'langfuse\tcredentials/config available but adapter not found\n' >> "$missing"
else
  printf 'langfuse\tcredentials/config not available and adapter not found\n' >> "$missing"
fi

missing_count="$(( $(wc -l < "$missing") - 1 ))"
input_count="$((codex_count + claude_count + pi_count + cursor_count + task_board_count + langfuse_count))"
evidence="なし"
if [ "${#evidence_ids[@]}" -gt 0 ]; then
  evidence="$(printf '%s\n' "${evidence_ids[@]}" | head -n 3 | awk 'BEGIN{ORS=""} {if(NR>1)printf ", "; printf "%s",$0}')"
fi

failure_category_summary="$work_dir/failure-category-summary.tsv"
sort -u -t $'\t' -k1,1 -k2,2 "$failure_category_log" | awk -F '\t' '
  NF >= 2 {
    count[$1]++
    ids[$1] = (ids[$1] ? ids[$1] ", " : "") $2
  }
  END {
    for (category in count) printf "%d\t%s\t%s\n", count[category], category, ids[category]
  }
' | sort -t $'\t' -k1,1nr -k2,2 > "$failure_category_summary"

proposal_kinds=()
proposal_categories=()
proposal_counts=()
proposal_evidences=()
while IFS=$'\t' read -r recurring_count recurring_category recurring_evidence; do
  [ -n "$recurring_category" ] || continue
  [ "$recurring_count" -ge 2 ] || continue
  [ "${#proposal_kinds[@]}" -lt 3 ] || break
  proposal_kinds+=("structured-failure-review")
  proposal_categories+=("$recurring_category")
  proposal_counts+=("$recurring_count")
  proposal_evidences+=("$recurring_evidence")
done < "$failure_category_summary"
if [ "$invalid_json" -gt 0 ] && [ "${#proposal_kinds[@]}" -lt 3 ]; then
  proposal_kinds+=("broken-jsonl"); proposal_categories+=(""); proposal_counts+=(""); proposal_evidences+=("")
fi
if [ "$missing_count" -gt 0 ] && [ "${#proposal_kinds[@]}" -lt 3 ]; then
  proposal_kinds+=("missing-source"); proposal_categories+=(""); proposal_counts+=(""); proposal_evidences+=("")
fi
proposal_count="${#proposal_kinds[@]}"

report="$artifact/report.md"
{
  echo "# 日次AI振り返り - $target_date"
  echo
  echo "## 実行サマリー"
  echo "- 対象期間: $target_date 00:00:00 以上、翌日 00:00:00 未満（$time_zone）"
  echo "- 入力件数: $input_count（Codex $codex_count / Claude Code $claude_count / Pi agent $pi_count / Cursor $cursor_count / Task Board $task_board_count / Langfuse $langfuse_count）"
  echo "- 構造化metrics: token total $token_total / duration total ${duration_ms_total}ms（値を持つsession $metric_files 件。欠損値は0扱いせず未観測）"
  echo "- 欠損ソース数: $missing_count（詳細: missing-sources.tsv）"
  echo "- 改善候補数: $proposal_count（上限3）"
  echo "- 安全境界: レポートと提案のみ。リポジトリ、agent設定、skill、rules、クラスタは変更していない。"
  echo
  echo "## うまくいった運用"
  if [ "$success_files" -gt 0 ]; then echo "- 明示的な完了イベントが $success_files セッションで確認できた。"; else echo "- 当日入力から機械判定できる明示的な完了イベントはなかった。人間レビューで補完する。"; fi
  echo
  echo "## つまずいた運用"
  if [ "$failure_files" -gt 0 ]; then echo "- 構造化されたerror / failed status / tool errorを持つセッションが $failure_files 件あった（本文は転載しない）。"; else echo "- 構造化された失敗記録を持つセッションはなかった。"; fi
  [ "$invalid_json" -eq 0 ] || echo "- JSONLとして読めない入力が $invalid_json 件あり、そのsourceだけ縮退した。"
  [ "$missing_count" -eq 0 ] || echo "- 到達不能または当日履歴なしのsourceが $missing_count 件あったが、他sourceの処理は継続した。"
  echo
  echo "## 観察根拠"
  echo "- 識別子: $evidence"
  echo "- 集計根拠: input-inventory.tsv（raw prompt / responseは記録しない）"
  echo
  echo "## 構造化失敗の分類別集計"
  if [ -s "$failure_category_summary" ]; then
    while IFS=$'\t' read -r category_count category_key category_evidence; do
      echo "- 分類キー: $category_key / distinct session件数: $category_count / 識別子: $category_evidence"
    done < "$failure_category_summary"
  else
    echo "- 構造化された失敗分類はなかった。"
  fi
  echo
  echo "## 恒久化すべき変更候補（最大3件）"
  if [ "$proposal_count" -eq 0 ]; then
    echo "- 今回は恒久化条件（同種の再発、または高い失敗コスト）を満たす候補なし。"
  else
    index=0
    while [ "$index" -lt "$proposal_count" ]; do
      proposal="${proposal_kinds[$index]}"
      recurring_failure_category="${proposal_categories[$index]}"
      recurring_failure_count="${proposal_counts[$index]}"
      recurring_failure_evidence="${proposal_evidences[$index]}"
      index=$((index + 1))
      echo
      echo "### 候補$index: $proposal"
      case "$proposal" in
        structured-failure-review)
          echo "- 対象: 複数agent"; echo "- 変更場所: 原因分類に対応するskill / rules / adapter（人間承認後に別ticketで特定）"; echo "- 変更内容: 同じ原因分類を持つsessionの共通対処を人間が調査し、恒久化の採否を判断する"; echo "- 分類キー: $recurring_failure_category"; echo "- distinct session件数: $recurring_failure_count"; echo "- 根拠識別子: $recurring_failure_evidence"; echo "- 観察根拠: 同じ原因分類を持つ異なるsessionが $recurring_failure_count 件"; echo "- 期待効果: 対処を共有できる再発だけを恒久化候補として扱える"; echo "- リスク: 同じ正規化signatureでも文脈が異なる可能性"; echo "- 優先度: P1"; echo "- 検証方法: 次回3営業日の分類別件数と根拠識別子を比較し、同分類2件以上だけが候補になることを確認" ;;
        broken-jsonl)
          echo "- 対象: 履歴adapter"; echo "- 変更場所: .claude/skills/end-of-day-ai-retro/scripts/"; echo "- 変更内容: 壊れたJSONLをsource単位で隔離し、欠損理由をartifactへ記録したうえで正常な履歴の集計を継続する"; echo "- 根拠識別子: input-inventory.tsv の invalid-jsonl 行"; echo "- 観察根拠: 壊れたJSONLが $invalid_json 件"; echo "- 期待効果: 欠損理由の明確化と部分処理の安定"; echo "- リスク: producer側障害を見逃す可能性"; echo "- 優先度: P2"; echo "- 検証方法: 壊れたfixtureと正常fixtureを混在させて正常分が残ることを確認" ;;
        missing-source)
          echo "- 対象: 履歴収集運用"; echo "- 変更場所: private vault / lolice（公開dotfilesへ固有値を置かない）"; echo "- 変更内容: 欠損sourceの保存設定・mount・権限をprivate環境で見直し、取得不能時は理由をrun artifactへ残す"; echo "- 根拠識別子: missing-sources.tsv"; echo "- 観察根拠: 欠損sourceが $missing_count 件"; echo "- 期待効果: 観察範囲の拡大"; echo "- リスク: 保存対象増加によるprivateデータ量の増加"; echo "- 優先度: P3"; echo "- 検証方法: 翌日runのsource別入力件数と欠損理由を確認" ;;
      esac
    done
  fi
  echo
  echo "## 翌日の変更案"
  echo "- 人間が上記候補を採用または理由付きで不採用にする。採用時だけTask Boardチケット化し、worktree / review / PRを通す。"
  echo
  echo "## 変更後の確認方法"
  echo "- 次回runの入力件数・欠損・同分類の失敗件数を比較し、悪化時はPRをrevertする。"
} > "$report"

"$SANITIZE_CHECK" "$report" >/dev/null

missing_edn="$(tail -n +2 "$missing" | awk -F '\t' 'BEGIN{printf "["} {gsub(/\\/,"\\\\",$2); gsub(/\"/,"\\\"",$2); if(NR>1)printf " "; printf "{:source \"%s\" :reason \"%s\"}",$1,$2} END{print "]"}')"
cat > "$artifact/run-summary.edn" <<EOF
{:target-date "$target_date"
 :time-zone "$time_zone"
 :executed-at "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
 :input-count $input_count
 :session-count {:codex $codex_count :claude $claude_count :pi $pi_count :cursor $cursor_count}
 :task-board-runs $task_board_count
 :langfuse-traces $langfuse_count
 :invalid-jsonl $invalid_json
 :completed-sessions $success_files
 :metrics {:files $metric_files :token-total $token_total :duration-ms-total $duration_ms_total}
 :missing-sources $missing_edn
 :proposal-count $proposal_count
 :automatic-changes false}
EOF

if [ "$dry_run" = true ]; then
  cat "$report"
else
  destination="$output_root/$target_date"
  mkdir -p "$output_root"
  replacement="$output_root/.${target_date}.tmp.$$"
  rm -rf "$replacement"
  cp -R "$artifact" "$replacement"
  rm -rf "$destination"
  mv "$replacement" "$destination"
  printf '%s\n' "$destination"
fi
