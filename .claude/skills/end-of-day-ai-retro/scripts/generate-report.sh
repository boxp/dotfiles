#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SESSION_FILES="$SCRIPT_DIR/session-files.sh"
target_date="$(date +%F)"
output_path=""
dry_run=false
missing_sources=()

usage() {
  cat <<'USAGE'
Usage: generate-report.sh [--date YYYY-MM-DD] [--output PATH] [--dry-run]
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --date) target_date="${2:?--date requires YYYY-MM-DD}"; shift 2 ;;
    --output) output_path="${2:?--output requires PATH}"; shift 2 ;;
    --dry-run) dry_run=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if ! date -d "$target_date" +%F >/dev/null 2>&1 && ! date -j -f '%Y-%m-%d' "$target_date" +%F >/dev/null 2>&1; then
  echo "Invalid date: $target_date" >&2
  exit 1
fi

session_status=0
session_output="$("$SESSION_FILES" retro --date "$target_date" 2>&1)" || { session_status=$?; true; }
if [ "$session_status" -ne 0 ]; then
  missing_sources+=("session-files: ${session_output:-実行に失敗}")
fi

count_agent() {
  local agent="$1"
  awk -F'|' -v agent="$agent" '
    /^## Largest sessions/ { exit }
    $2 ~ "^[[:space:]]*" agent "[[:space:]]*$" { count++ }
    END { print count + 0 }
  ' <<<"$session_output"
}

codex_count="$(count_agent codex)"
claude_count="$(count_agent claude)"
pi_count="$(count_agent pi)"
cursor_count="$(count_agent cursor)"

task_board_count=0
task_board_root="$HOME/.codex-task-board/workspaces"
compact_date="${target_date//-/}"
if [ -d "$task_board_root" ]; then
  task_board_count="$(find "$task_board_root" -mindepth 2 -maxdepth 2 -type d \( -name "${target_date}*" -o -name "${compact_date}*" \) -print 2>/dev/null | wc -l | tr -d ' ' || true)"
  if [ "$task_board_count" -eq 0 ]; then
    missing_sources+=("Task Board: 当日runディレクトリが見つからない")
  fi
else
  missing_sources+=("Task Board: $task_board_root が存在しない")
fi

if [ -z "${LANGFUSE_PUBLIC_KEY:-}" ]; then
  missing_sources+=("Langfuse: LANGFUSE_PUBLIC_KEY が設定されていない")
fi

if [ "${#missing_sources[@]}" -eq 0 ]; then
  missing_summary="なし"
else
  missing_summary="$(IFS='; '; echo "${missing_sources[*]}")"
fi

report="$(cat <<EOF
## 日次振り返りレポート - $target_date

### 実行サマリー
- 対象日: $target_date
- 実行時刻: $(date -u +%Y-%m-%dT%H:%M:%SZ)
- セッション数: codex:$codex_count claude:$claude_count pi:$pi_count cursor:$cursor_count
- Task Board runs: $task_board_count
- 欠損ソース: $missing_summary

### 今日うまくいった運用
- （セッションを確認して記入）

### 今日つまずいた運用
- （セッションを確認して記入）

### セッションファイルで確認した事実
- agent:
- file:
- 観察内容:
- そこから分かること:

### 恒久化すべき変更候補（最大3件）

#### 候補1
- 対象:
- 変更場所:
- 観察根拠 (session/trace/ticket識別子):
- 変更内容:
- 期待効果:
- リスク:
- 優先度: P1/P2/P3
- 検証方法:

### 翌日の変更案
- （候補から選んで記入）

### 変更後の確認方法
- （各変更に対して記入）
EOF
)"

if [ "$dry_run" = true ] || [ -z "$output_path" ]; then
  printf '%s\n' "$report"
else
  mkdir -p "$(dirname "$output_path")"
  printf '%s\n' "$report" > "$output_path"
fi
