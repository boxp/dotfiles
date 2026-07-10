# BOXP-87: 日次AI振り返り自動化 計画・設計

## 目的と決定

既存の `end-of-day-ai-retro` と lolice の resident `codex-cron-scheduler` を使い、その日の履歴を根拠に最大3件の改善候補を private vault へ保存する。MVPは提案までで停止し、設定・skill・repository・clusterを自動変更しない。

レビュー対象は次の3点である。

1. public dotfilesの汎用collector、秘匿境界、fixtureテスト
2. private vaultのlive job、prompt、日次report/run artifact
3. dry-run成果物に対する「採用して別ticket化 / 理由付き不採用」の人間判断

## 一次資料（2026-07-10参照）

- Claude Code: [Hooks](https://code.claude.com/docs/en/hooks), [Skills](https://code.claude.com/docs/en/slash-commands), [Permissions](https://code.claude.com/docs/en/permissions), [Monitoring](https://code.claude.com/docs/en/monitoring-usage)
- Codex: [Customization](https://developers.openai.com/codex/concepts/customization), [Scheduled tasks](https://developers.openai.com/codex/app/automations), [Advanced configuration](https://developers.openai.com/codex/config-advanced)
- Hermes Agent: [official repository](https://github.com/NousResearch/hermes-agent), [Skills System](https://hermes-agent.nousresearch.com/docs/user-guide/features/skills/)
- OpenClaw: [official repository](https://github.com/openclaw/openclaw), [Memory](https://docs.openclaw.ai/concepts/memory), [Skills](https://docs.openclaw.ai/tools/skills)

Codex manual helperはレスポンスの `x-content-sha256` 不足で取得できなかったため、公式Webドキュメントへfallbackした。断定は上記一次資料で確認できる範囲に限定する。

## 比較と採否

| 軸 | Claude Code | Codex | Hermes Agent | OpenClaw | MVPでの判断 |
|---|---|---|---|---|---|
| 履歴・観測 | session JSONLを利用可能。HooksはSessionEnd/StopFailure等、OTelはattempt/success/error/tool情報を出せる | local sessionを利用可能。OTelはduration/error/token等を持ち、prompt内容は明示設定なしではredact | session reviewとmemory/skill reviewを備える | daily memory、DREAMS、background consolidationを備える | 当日local session、Task Board、到達可能なtraceを入力。本文はartifactへ転載しない |
| memory / skill分離 | CLAUDE.mdは常時指示、skill本文は使用時にload | memoryは過去context、AGENTSは永続指示、skillは再利用手順。skillは段階的load | memoryは短いdurable fact、skillは長いprocedure。background reviewで候補化可能 | MEMORY.mdはcurated、daily noteはworking layer、skillはprocedure | 成功・摩擦の観察と、変更先候補を分離。raw observationをdurable ruleへ直結させない |
| 段階的開示 | skill metadataをdiscoverし本文を必要時load | metadata → SKILL.md → reference/script | Level 0 metadata → Level 1本文 → Level 2個別reference | MEMORY.mdを小さく保ち詳細はdaily note/searchへ | 採用。collectorは識別子/集計だけ、詳細調査はprivate reviewerが上位候補のみ読む |
| 定期review | hook/外部schedulerで構成可能 | scheduled taskをworktree分離・sandbox最小権限で実行可能 | background reviewがmemory/skill変更をsuggest/stage可能 | opt-in dreamingがscore/頻度/多様性でpromote候補を絞る | 既存codex-cron-schedulerを使用。新schedulerは作らない |
| 人間承認 | permissions/hooks、plan modeでread-only提案が可能 | approval policy/sandbox。scheduled taskも最小権限を推奨 | skill write approvalとmemory write approvalを設定可能 | DREAMS.mdはreview surfaceだがdeep promotionはMEMORY.mdを書き得る | Hermesのapproval gateという考え方を採用。MVPは常にproposal-onlyで、人間承認後に別ticket化 |
| 回帰確認 | hookでtest、PR review | test/lint/PR review、worktree隔離 | pending diffをreview可能 | threshold/structured reviewあり | 候補ごとに期待効果・risk・検証方法を必須化し、次回runで件数比較 |
| rollback | git/revert | git/revert、worktree破棄 | pending変更ならreject可能 | backfillにはrollbackがあるが、live deep promotionとは境界が異なる | public変更は通常PRのrevert、private日次artifactは対象日keyで再生成 |
| safety | deny/ask/allow、hooks | sandbox/approval。prompt telemetryはdefault redact | agent-created skillはscannerとapproval gateが別 | memoryはworkspace fileとして書込み | unattended runはreport/private proposal以外を書かない。`bypass-approvals=false` |

### 採用

- Codex/Claude/Hermesの段階的skill loadと、memory（短い事実）/skill（長い手順）の分離。
- Hermesのwrite-approval gate相当を、より強い「MVPは自動write禁止」で実現する。
- OpenClawのdaily working layer / curated durable layer、score・再発回数で昇格を絞る考え方。
- Codexのscheduled taskにおけるworktree分離・最小sandboxの原則。ただし本件はrepoを開かずprivate artifactのみを作る。

### 不採用・保留

- Hermes/OpenClaw本体の導入: 既存schedulerとskillで要件を満たせ、新しい実行基盤を増やすため不採用。
- 無審査のmemory/skill promotion: 誤分類、private情報の永続化、rollback範囲の不明瞭さがあるため不採用。Hermesには承認gateがあるので「Hermesは常に無承認」とは扱わない。
- OpenClawのdeep promotion: staged backfillとrollbackは参考にするが、live promotionがdurable memoryを書き得るためMVPでは採用しない。
- 単一sessionだけを根拠にした恒久化: 高コスト事故を除き、同分類が複数観測されるまで候補にしない。

## 入力adapterと縮退

| source | 当日抽出 | 欠損時 |
|---|---|---|
| Codex | `${AI_RETRO_CODEX_ROOT:-~/.codex/sessions}/**/*.jsonl` のmtime | `directory not found` / `no files for target date` |
| Claude Code | `${AI_RETRO_CLAUDE_ROOT:-~/.claude/projects}/**/*.jsonl` のmtime | 同上 |
| Pi agent | `${AI_RETRO_PI_ROOT:-~/.pi/agent/sessions}/**/*.jsonl` のmtime | 同上 |
| Cursor（補助） | `${AI_RETRO_CURSOR_ROOT:-~/.cursor/projects}/**/agent-transcripts/*.jsonl` のmtime | 同上 |
| Task Board | `~/.codex-task-board/workspaces/*/<YYYYMMDD>T*` | 当日runなし / rootなし |
| Langfuse | credential/configと専用adapterが到達可能な場合のみ | credentialなし、adapter到達不能を明記 |

1 sourceの欠損・壊れたJSONLはrun全体を失敗させない。`input-inventory.tsv` と `missing-sources.tsv` にsource・秘匿済みidentifier・理由を残す。

## Public / private境界

| 配置 | 許可 | 禁止 |
|---|---|---|
| `boxp/dotfiles` (public) | 汎用skill、collector、判定規則、架空fixture、test、secretを含まない設計 | raw prompt/response、credential、email、private IP、cluster固有host/path、実日次report |
| `boxp/lolice` | mount/resource/timeout等のGitOps設定（変更が必要な場合のみ） | raw session、credential値、個人固有prompt |
| private Obsidian vault | live schedule/prompt、report、run artifact、秘匿済み提案 | secretのreport転載、public PRへのraw evidence転記 |

根拠は `agent:<pathの短縮SHA-256>`、`ticket-run:TICKET/run-id`、`trace-id` と秘匿済み集計に限定する。session path/filename、本文、コマンド全文、user情報は保存しない。

## Artifact・冪等性・安全境界

対象日keyは `--time-zone` で指定したIANA timezoneでの `YYYY-MM-DD`。mtimeのday境界も同じtimezoneで計算する。同日再実行は `<root>/<date>` を一度だけ置換し、追記しない。

```text
<private-root>/<YYYY-MM-DD>/
  report.md
  run-summary.edn
  missing-sources.tsv
  input-inventory.tsv
```

`run-summary.edn` は対象日、timezone、実行時刻、source別件数、入力総数、利用可能なtoken/latency metrics、壊れたJSONL、欠損理由、候補数、`:automatic-changes false` を持つ。日次処理が許可するwriteはこのprivate artifactだけ。repo、`~/.claude`、`~/.codex`、稼働中cluster、Task Board cardを変更しない。

採用候補は人間が別Task Board ticketにし、通常のworktree / review / PR / testを経る。悪化した変更はPRをrevertする。

## 検証計画と完了条件

- fixture: 成功、同分類失敗2件、履歴なし、壊れたJSONL、secret様文字列、同日再実行。
- `bash tests/run-tests.sh`、`bash -n`、利用可能なら`ShellCheck`、既存dotfiles setup検証。
- live jobを指定timezoneの1日1回で登録し、`bypass-approvals=false` を確認。
- 実環境の1日をmanual validation runし、artifact、最大3件、秘匿、縮退、非自動変更を確認。
- 人間はdry-run reportの候補を少なくとも1件、別ticket化するか理由付きで不採用にする。

## 実装順

1. public collector/test/documentationをPR化する。
2. private jobをdisabledで登録し、manual validation runする。
3. artifactを確認後、一日1回のjobをenableする。
4. 人間判断をticket Notesへ残す。
