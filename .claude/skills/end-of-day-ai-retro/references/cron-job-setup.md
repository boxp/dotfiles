# Codex Cron Job セットアップ手順

## 前提

- `boxp/lolice` の `codex-cron-scheduler` sidecar が稼働していること
- Obsidian vault が `/home/boxp/Documents/obsidian-headless/BOXP/` に同期されていること

## Private Vault への設定手順

以下はすべて private な Obsidian vault または lolice repo に記録する。dotfiles には置かない。

### 1. プロンプトファイルの作成（private vault）

`/home/boxp/Documents/obsidian-headless/BOXP/Infrastructure/Codex Cron/prompts/end-of-day-retro.md` を作成する。内容は終業時AI振り返りの指示（対象日のセッション一覧確認、`generate-report.sh` 実行、レポートをprivate vault runs/に保存する手順）を含む。生セッション内容・secretは含めない。

### 2. jobs.edn への追加（private vault）

`/home/boxp/Documents/obsidian-headless/BOXP/Infrastructure/Codex Cron/jobs.edn` に以下のエントリを追加:

```clojure
{:id "end-of-day-retro"
 :name "End-of-day AI retrospective"
 :enabled false
 :schedule "0 22 * * 1-5"
 :time-zone "Asia/Tokyo"
 :prompt-file "prompts/end-of-day-retro.md"
 :workdir "/home/boxp"
 :output-root "/home/boxp/Documents/obsidian-headless/BOXP/Infrastructure/Codex Cron/runs"
 :bypass-approvals false}
```

注意: enabled は初期値 false。dry-run検証後に手動で true に変更する。

### 3. 冪等性の確保

同一対象日の再実行で重複しないよう、run artifactのディレクトリは対象日をキー（YYYY-MM-DD）とし上書きにする。

### 4. 有効化（dry-run確認後）

```bash
bb ~/.codex/skills/codex-workspace-cron/scripts/codex_cron_jobs.bb enable end-of-day-retro
```

## Run Artifact の構造

```
/runs/end-of-day-retro/YYYY-MM-DD/
  report.md           # 日次レポート（最大3件の改善候補）
  run-summary.edn     # 実行メタデータ
  missing-sources.txt # 欠損ソースと理由
```

run-summary.edn の形式:

```clojure
{:target-date "YYYY-MM-DD"
 :executed-at "YYYY-MM-DDTHH:MM:SSZ"
 :session-count {:codex N :claude N :pi N :cursor N}
 :task-board-runs N
 :missing-sources [{:source "langfuse" :reason "LANGFUSE_PUBLIC_KEY not set"}]
 :proposal-count N}
```

## MVPの日次実行の範囲

- レポート生成と proposals 保存まで
- リポジトリ、~/.claude、~/.codex、稼働中クラスタを自動変更しない
- 採用する変更は人間の承認後にTask Board → worktree → PRフローを通す
