# Codex Cron Job セットアップ・検証

live registryはprivate Obsidian vaultの `Infrastructure/Codex Cron/jobs.edn`。個別Kubernetes CronJobや別schedulerは作らない。操作は `codex-workspace-cron` skillのhelperだけを使う。

## Prompt

private vaultの `Infrastructure/Codex Cron/prompts/end-of-day-ai-retro.md` に次を含める。

- `TZ=Asia/Tokyo date +%F` を対象日にする。
- `generate-report.sh --date ... --time-zone Asia/Tokyo --output-root <private report root>` を1回実行する。
- `report.md` / `run-summary.edn` / `missing-sources.tsv` / `input-inventory.tsv` を確認する。
- raw session、secret、token、個人情報、cluster固有値を回答やpublic repoへ転載しない。
- repo、`~/.claude`、`~/.codex`、skill、rules、Task Board、clusterを変更しない。
- 人間向けに対象日、入力件数、欠損、候補数、artifact pathだけを要約する。

## 登録

初回はdisabledで登録し、schedule/timezone/prompt/bypass設定を確認する。

```bash
bb ~/.codex/skills/codex-workspace-cron/scripts/codex_cron_jobs.bb add \
  --id end-of-day-ai-retro \
  --name "End-of-day AI retrospective" \
  --schedule "0 22 * * *" \
  --time-zone "Asia/Tokyo" \
  --workdir "<workspace directory>" \
  --output-root "<private scheduler artifact root>" \
  --bypass-approvals false \
  --prompt-source "/private/path/end-of-day-ai-retro.md"
```

`output-root` はscheduler自身のevents/stderr/last-message/summary保存先であり、日次reportの保存先はprompt内の `generate-report.sh --output-root` で指定する。
実環境の絶対path、cluster固有のmount先、user名はpublic dotfilesへ記録せず、private vault側の運用手順で管理する。

## Manual validationと有効化

ticketが要求するvalidation runでは次を実行できる。

```bash
bb ~/.codex/skills/codex-workspace-cron/scripts/codex_cron_jobs.bb run end-of-day-ai-retro
```

確認項目:

1. scheduler runが終了し、private report artifactが作られた。
2. 候補は0〜3件で、各候補に対象、変更場所、根拠identifier、期待効果、risk、優先度、検証方法がある。`structured-failure-review` は分類キー、distinct session件数、該当する秘匿済み識別子も持つ。
3. 欠損sourceが明示され、利用可能sourceの処理は残る。
4. sensitive checkerが通り、`:automatic-changes false` である。
5. 同じ対象日を再実行して対象日directoryが1つ、候補数が増殖しない。
6. 構造化失敗の分類別集計は件数降順・分類キー昇順で、distinct sessionが2件未満の分類は候補にならない。

確認後に一日1回のjobを有効化する。

```bash
bb ~/.codex/skills/codex-workspace-cron/scripts/codex_cron_jobs.bb enable end-of-day-ai-retro
```

採用する候補は人間が別Task Board ticketにし、通常のworktree / review / PRへ渡す。日次job自身は実装しない。
