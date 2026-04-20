#!/usr/bin/env bash
set -euo pipefail

# xAI Grok Web検索スクリプト

# XAI_API_KEYチェック
if [ -z "${XAI_API_KEY:-}" ]; then
  echo "Error: XAI_API_KEY environment variable is not set" >&2
  exit 1
fi

# 引数チェック
if [ $# -eq 0 ]; then
  echo "Usage: $0 <search_query>" >&2
  echo "Example: $0 'React hooks best practices'" >&2
  exit 1
fi

# 検索クエリ（JSONエスケープ）
QUERY=$(printf '%s' "$*" | jq -Rs .)

# APIリクエスト
RESPONSE=$(curl -s https://api.x.ai/v1/responses \
  -H "Authorization: Bearer $XAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"model\": \"grok-4-1-fast-reasoning\",
    \"tools\": [{\"type\": \"web_search\"}],
    \"input\": $QUERY
  }")

# エラーチェック
if echo "$RESPONSE" | jq -e '.error' >/dev/null 2>&1; then
  echo "API Error:" >&2
  echo "$RESPONSE" | jq -r '.error.message // .error' >&2
  exit 1
fi

# テキスト部分のみ抽出して表示
TEXT=$(echo "$RESPONSE" | jq -r '
  .output[]
  | select(.type == "message")
  | .content[]
  | select(.type == "output_text")
  | .text
' 2>/dev/null)

if [ -n "$TEXT" ]; then
  echo "$TEXT"
else
  # フォールバック: output全体を表示
  echo "$RESPONSE" | jq -r '.output // .'
fi
