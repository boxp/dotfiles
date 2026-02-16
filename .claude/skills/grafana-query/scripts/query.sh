#!/usr/bin/env bash
set -euo pipefail

# Grafana API クエリスクリプト
# Usage: query.sh <subcommand> [args...]
#   query.sh promql <query>           - PromQLクエリを実行
#   query.sh dashboards [search]      - ダッシュボード一覧/検索
#   query.sh alerts                   - アラート一覧
#   query.sh datasources              - データソース一覧

# 環境変数チェック
if [ -z "${GRAFANA_URL:-}" ]; then
  echo "Error: GRAFANA_URL environment variable is not set" >&2
  exit 1
fi
if [ -z "${GRAFANA_API_KEY:-}" ]; then
  echo "Error: GRAFANA_API_KEY environment variable is not set" >&2
  exit 1
fi

# 引数チェック
if [ $# -eq 0 ]; then
  echo "Usage: $0 <subcommand> [args...]" >&2
  echo "Subcommands:" >&2
  echo "  promql <query>        - Execute PromQL query" >&2
  echo "  dashboards [search]   - List/search dashboards" >&2
  echo "  alerts                - List alerts" >&2
  echo "  datasources           - List datasources" >&2
  exit 1
fi

AUTH_HEADER="Authorization: Bearer ${GRAFANA_API_KEY}"
SUBCOMMAND="$1"
shift

case "$SUBCOMMAND" in
  promql)
    if [ $# -eq 0 ]; then
      echo "Error: PromQL query required" >&2
      echo "Usage: $0 promql <query>" >&2
      exit 1
    fi
    QUERY="$*"
    DATASOURCE_ID="${GRAFANA_DATASOURCE_ID:-1}"
    ENCODED_QUERY=$(printf '%s' "$QUERY" | jq -sRr @uri)
    RESPONSE=$(curl -sf \
      -H "$AUTH_HEADER" \
      "${GRAFANA_URL}/api/datasources/proxy/${DATASOURCE_ID}/api/v1/query?query=${ENCODED_QUERY}" 2>&1) || {
      echo "Error: Grafana API request failed" >&2
      echo "$RESPONSE" >&2
      exit 1
    }
    echo "$RESPONSE" | jq '.'
    ;;

  dashboards)
    SEARCH="${*:-}"
    if [ -n "$SEARCH" ]; then
      ENCODED_SEARCH=$(printf '%s' "$SEARCH" | jq -sRr @uri)
      URL="${GRAFANA_URL}/api/search?query=${ENCODED_SEARCH}&type=dash-db"
    else
      URL="${GRAFANA_URL}/api/search?type=dash-db"
    fi
    RESPONSE=$(curl -sf \
      -H "$AUTH_HEADER" \
      "$URL" 2>&1) || {
      echo "Error: Grafana API request failed" >&2
      echo "$RESPONSE" >&2
      exit 1
    }
    echo "$RESPONSE" | jq '.[] | {title, uid, url, tags}'
    ;;

  alerts)
    RESPONSE=$(curl -sf \
      -H "$AUTH_HEADER" \
      "${GRAFANA_URL}/api/alerting/alerts" 2>&1) || {
      echo "Error: Grafana API request failed" >&2
      echo "$RESPONSE" >&2
      exit 1
    }
    echo "$RESPONSE" | jq '.'
    ;;

  datasources)
    RESPONSE=$(curl -sf \
      -H "$AUTH_HEADER" \
      "${GRAFANA_URL}/api/datasources" 2>&1) || {
      echo "Error: Grafana API request failed" >&2
      echo "$RESPONSE" >&2
      exit 1
    }
    echo "$RESPONSE" | jq '.[] | {id, name, type, url}'
    ;;

  *)
    echo "Error: Unknown subcommand '$SUBCOMMAND'" >&2
    echo "Valid subcommands: promql, dashboards, alerts, datasources" >&2
    exit 1
    ;;
esac
