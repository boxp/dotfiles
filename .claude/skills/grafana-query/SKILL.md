---
name: grafana-query
description: Grafana APIでPromQLクエリ・ダッシュボード検索・アラート確認。「メトリクス確認」「CPU使用率」「メモリ使用量」「ダッシュボード検索」「アラート状態」「Grafanaで確認」時に使用
argument-hint: <promql|dashboards|alerts|datasources> [args...]
---

# Grafana クエリスキル

Grafana HTTP API を使用してメトリクス・ダッシュボード・アラートを取得します。

## 実行方法

**このスキルはメインコンテキストを消費しないよう、必ずTaskツール（subagent_type=Bash）で実行すること。**

```
Task tool:
  subagent_type: Bash
  prompt: |
    bash /home/node/.claude/skills/grafana-query/scripts/query.sh $ARGUMENTS
```

Taskの結果を受け取ったら、内容を日本語で要約してユーザーに提示する。

## サブコマンド

### PromQLクエリ
```bash
bash /home/node/.claude/skills/grafana-query/scripts/query.sh promql "up"
bash /home/node/.claude/skills/grafana-query/scripts/query.sh promql "rate(container_cpu_usage_seconds_total[5m])"
bash /home/node/.claude/skills/grafana-query/scripts/query.sh promql "container_memory_working_set_bytes{namespace='openclaw'}"
```

### ダッシュボード検索
```bash
bash /home/node/.claude/skills/grafana-query/scripts/query.sh dashboards
bash /home/node/.claude/skills/grafana-query/scripts/query.sh dashboards "openclaw"
```

### アラート一覧
```bash
bash /home/node/.claude/skills/grafana-query/scripts/query.sh alerts
```

### データソース一覧
```bash
bash /home/node/.claude/skills/grafana-query/scripts/query.sh datasources
```

## 環境変数

- `GRAFANA_URL`: Grafana URL（Pod環境変数として設定済み）
- `GRAFANA_API_KEY`: Grafana Service Account Token（Secretから注入済み）
- `GRAFANA_DATASOURCE_ID`: データソースID（デフォルト: 1）

## よく使うPromQLクエリ例

- `up` - ターゲット稼働状態
- `openclaw_tokens_total` - OpenClawトークン使用量
- `openclaw_cost_usd` - OpenClaw推定コスト
- `container_cpu_usage_seconds_total{namespace="openclaw"}` - CPU使用率
- `container_memory_working_set_bytes{namespace="openclaw"}` - メモリ使用量
- `kube_pod_status_phase{namespace="openclaw"}` - Pod状態
