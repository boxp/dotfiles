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
  jq -c --argjson start "$start" --argjson end "$end" '
    def timestamp_field:
      if has("timestamp") then {present: true, value: .timestamp}
      elif ((.payload? | type) == "object" and (.payload | has("timestamp"))) then {present: true, value: .payload.timestamp}
      elif ((.message? | type) == "object" and (.message | has("timestamp"))) then {present: true, value: .message.timestamp}
      elif has("created_at") then {present: true, value: .created_at}
      elif has("createdAt") then {present: true, value: .createdAt}
      elif has("startTime") then {present: true, value: .startTime}
      elif has("time") then {present: true, value: .time}
      else {present: false, value: null}
      end;
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
    timestamp_field as $timestamp |
    if ($timestamp.present | not) then {kind: "absent"}
    else ($timestamp.value | timestamp_epoch) as $epoch |
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
  local file="$1" record lowered digest category
  while IFS= read -r record; do
    [ -n "$record" ] || continue
    lowered="$(printf '%s' "$record" | tr '[:upper:]' '[:lower:]')"
    case "$lowered" in
      __nonzero_exit__) category="nonzero-exit" ;;
      *permission*|*access\ denied*|*operation\ not\ permitted*|*forbidden*) category="permission" ;;
      *unauthorized*|*authentication*|*credential*) category="authentication" ;;
      *timed\ out*|*timeout*|*deadline\ exceeded*) category="timeout" ;;
      *rate\ limit*|*too\ many\ requests*|*quota*|*'"429"'*) category="rate-limit" ;;
      *connection*|*network*|*dns*|*host\ unreachable*) category="network" ;;
      *not\ found*|*no\ such\ file*|*'"404"'*) category="not-found" ;;
      *)
        digest="$(printf '%s' "$record" | { sha256sum 2>/dev/null || shasum -a 256; } | awk '{print substr($1,1,12)}')"
        category="error-signature-$digest"
        ;;
    esac
    printf '%s\n' "$category"
  done < <(jq -scr '.[] |
    select(
      (.type? == "error") or (.payload.type? == "error") or
      (.status? == "failed") or (.payload.status? == "failed") or (.is_error? == true) or
      any(.message.content[]?; .type == "tool_result" and .is_error == true) or
      ((.type? == "response_item") and ((.payload.type? // "") | test("tool.*output")) and
        ((.payload.output // "") | tostring | test("\\\"exit_code\\\":[1-9]")))) |
    if ((.type? == "response_item") and ((.payload.type? // "") | test("tool.*output")) and
      ((.payload.output // "") | tostring | test("\\\"exit_code\\\":[1-9]")))
    then "__NONZERO_EXIT__"
    else (walk(if type == "object" then del(.timestamp, .created_at, .updated_at, .id, .uuid) else . end) | @json)
    end' "$file" | sort -u)
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
      file_tokens="$(jq -sr '([.[] | .payload.info.total_token_usage.total_tokens? // empty] | max // 0) | floor' "$analysis_file")"
      file_duration="$(jq -sr '([.[] | .payload.duration_ms? // empty] | add // 0) | floor' "$analysis_file")"
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

proposals=()
recurring_failure_category=""
recurring_failure_count=0
recurring_failure_evidence=""
recurring_failure_record="$(awk -F '\t' '
  { count[$1]++; ids[$1] = (ids[$1] ? ids[$1] ", " : "") $2 }
  END { for (category in count) if (count[category] >= 2) printf "%d\t%s\t%s\n", count[category], category, ids[category] }
' "$failure_category_log" | sort -t $'\t' -k1,1nr -k2,2 | head -n 1)"
if [ -n "$recurring_failure_record" ]; then
  IFS=$'\t' read -r recurring_failure_count recurring_failure_category recurring_failure_evidence <<< "$recurring_failure_record"
fi
if [ -n "$recurring_failure_category" ]; then proposals+=("structured-failure-review"); fi
if [ "$invalid_json" -gt 0 ]; then proposals+=("broken-jsonl"); fi
if [ "$missing_count" -gt 0 ]; then proposals+=("missing-source"); fi
proposal_count="${#proposals[@]}"
[ "$proposal_count" -le 3 ] || proposal_count=3

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
  echo "## 恒久化すべき変更候補（最大3件）"
  if [ "$proposal_count" -eq 0 ]; then
    echo "- 今回は恒久化条件（同種の再発、または高い失敗コスト）を満たす候補なし。"
  else
    index=0
    for proposal in "${proposals[@]}"; do
      index=$((index + 1)); [ "$index" -le 3 ] || break
      echo
      echo "### 候補$index: $proposal"
      case "$proposal" in
        structured-failure-review)
          echo "- 対象: 複数agent"; echo "- 変更場所: private daily-review prompt（承認後に別ticketで分類設計）"; echo "- 根拠識別子: $recurring_failure_evidence"; echo "- 観察根拠: 同じ失敗分類 $recurring_failure_category を持つsessionが複数（$recurring_failure_count 件）"; echo "- 期待効果: error種別を再発単位へ分け、恒久化に値する摩擦だけを選べる"; echo "- リスク: 同じ構造分類でも文脈が異なる可能性"; echo "- 優先度: P1"; echo "- 検証方法: 次回3営業日はerror種別別の件数を記録し、同分類2件以上のみ候補化する" ;;
        broken-jsonl)
          echo "- 対象: 履歴adapter"; echo "- 変更場所: .claude/skills/end-of-day-ai-retro/scripts/"; echo "- 根拠識別子: input-inventory.tsv の invalid-jsonl 行"; echo "- 観察根拠: 壊れたJSONLが $invalid_json 件"; echo "- 期待効果: 欠損理由の明確化と部分処理の安定"; echo "- リスク: producer側障害を見逃す可能性"; echo "- 優先度: P2"; echo "- 検証方法: 壊れたfixtureと正常fixtureを混在させて正常分が残ることを確認" ;;
        missing-source)
          echo "- 対象: 履歴収集運用"; echo "- 変更場所: private vault / lolice（公開dotfilesへ固有値を置かない）"; echo "- 根拠識別子: missing-sources.tsv"; echo "- 観察根拠: 欠損sourceが $missing_count 件"; echo "- 期待効果: 観察範囲の拡大"; echo "- リスク: 保存対象増加によるprivateデータ量の増加"; echo "- 優先度: P3"; echo "- 検証方法: 翌日runのsource別入力件数と欠損理由を確認" ;;
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
