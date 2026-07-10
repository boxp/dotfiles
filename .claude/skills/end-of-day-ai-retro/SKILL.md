---
name: end-of-day-ai-retro
description: 一日の Claude Code / Codex / Pi agent / Cursor セッションをローカルセッションファイルから振り返り、設定・rules・skills・フック・運用を改善する。終業時の振り返り、session retro、daily AI review、Claude/Codex の設定見直し、rules 改善、プロンプト改善をしたい時に使用
---

# 終業時 AI リフレクション

一日の終わりに、その日の Claude Code / Codex / Pi agent / Cursor の使い方を棚卸しし、翌日から効く設定改善に落とし込む。

目的は感想を書くことではなく、「何が詰まり、何が効き、何を設定へ昇格させるべきか」をローカルセッションファイルから抽出し、`~/.claude`、`~/.codex`、`~/.pi/agent`、Cursor 設定に対する具体的な変更案まで整理すること。

## 進め方

1. 今日の対象セッションファイルとsource別欠損を確定する
2. セッションの摩擦と成功パターンを集める
3. Claude Code / Codex / Pi agent / Cursor のどこに寄せる改善かを分ける
4. 一時的なプロンプト工夫ではなく、設定・skill・rules・hook に昇格させる候補を選ぶ
5. 変更案、期待効果、risk、優先度、検証方法を最大3件にまとめる
6. 日次自動実行ではprivate report/run artifactだけを保存し、変更は行わない

詳細な観点と出力テンプレートは `references/retro-checklist.md` を読む。セッションファイルの見方は `references/session-files-retro.md` も読む。

## 事前確認

- `Codex` の履歴を使うなら `~/.codex/config.toml` で次を確認する
  ```toml
  [history]
  persistence = "save-all"
  ```
- `Claude Code` 側も、`~/.claude/projects/**/*.jsonl` や通知フックを見返せる構成になっているか確認する
- `Pi agent` は `~/.pi/agent/sessions/**/*.jsonl` にセッションが残っているか確認する
- `Cursor` は `~/.cursor/projects/**/agent-transcripts/*.jsonl` にセッションが残っているか確認する
- Task Boardは `~/.codex-task-board/workspaces/*/<YYYYMMDD>T*`、Langfuseは利用可能なcredential/configとadapterを確認する
- repo 内 skill を改善候補に含める場合は、既存の `.claude/skills/` と `setup.sh` の有効化リストを確認する
- 単発の作業ミスではなく、再発しそうな摩擦を優先する

## 日次artifactを生成する

```bash
bash "$HOME/.claude/skills/end-of-day-ai-retro/scripts/generate-report.sh" \
  --date "$(TZ=Asia/Tokyo date +%F)" \
  --time-zone "Asia/Tokyo" \
  --output-root "/private/vault/path/AI Retro/runs"
```

同じ対象日は同じdirectoryを置換する。`report.md`、`run-summary.edn`、`missing-sources.tsv`、`input-inventory.tsv` を確認する。欠損・壊れたJSONLがあっても利用可能なsourceを残す。

構造化失敗は、認証・rate limit・権限・timeout・network・not-found等の対処単位と、timestamp、record ID、一時path等を除いた原因の短縮signatureで分類する。既知規則に一致しない非0終了とerrorも同じsignature方式へfallbackする。同じ分類は1sessionにつき1件と数え、異なる秘匿済みsession識別子が2件以上ある場合だけ `structured-failure-review` 候補にする。reportの分類別集計と、候補に記載された分類キー・distinct session件数・秘匿済み識別子を確認し、raw本文から原因を推測してreportへ追記しない。

Langfuseを集計する場合は、実行可能なadapterのpathを `AI_RETRO_LANGFUSE_ADAPTER` に指定する。未指定時はskill同階層の `scripts/langfuse-adapter.sh`、`~/.local/bin/end-of-day-ai-retro-langfuse-adapter`、同名の `PATH` commandを順に探す。adapterには `--start-epoch EPOCH --end-epoch EPOCH` を渡し、標準出力は1行1objectのJSONLとする。各objectには `id`（`traceId` / `trace_id` も可）と `timestamp`（`startTime` / `createdAt` / `created_at` も可）が必要。raw traceはartifactへ保存せず、対象期間内の件数と短縮SHA-256識別子だけを残す。adapterなし・実行失敗・不正recordは他sourceを止めず `missing-sources.tsv` に理由を記録する。

日次自動実行が変更してよいのはprivate artifactだけ。repo、`~/.claude`、`~/.codex`、skill、rules、Task Board、clusterを変更しない。候補の採用は人間承認後に別ticketとPRで行う。

## セッションファイルを使った観察手順

Codex / Claude / Pi agent / Cursor のローカルセッションファイルを観察根拠にする。特に次のような場面では、記憶ではなくセッションファイルを優先する。

- どのエージェントで何を依頼したかを確認したい
- 同じ指示、確認質問、作業停止、やり直しが繰り返されたか見たい
- tool call、長い出力、承認待ち、エラー、作業ディレクトリの迷いをセッション単位で見たい
- Codex / Claude / Pi agent / Cursor の使い分けが妥当だったか比較したい

### 1. まず今日のセッション一覧を見る

まず標準フローを使う。

```bash
bash "$HOME/.claude/skills/end-of-day-ai-retro/scripts/session-files.sh" retro --date "$(date +%F)" --limit 40 --top 12
```

これは今日更新されたセッションファイルをエージェント別に列挙し、サイズや行数が大きいものを上位候補として出す入口として使う。まずは毎回これを叩く。

必要に応じて絞り込む。

```bash
bash "$HOME/.claude/skills/end-of-day-ai-retro/scripts/session-files.sh" list --agent codex --date "$(date +%F)"
bash "$HOME/.claude/skills/end-of-day-ai-retro/scripts/session-files.sh" list --agent claude --date "$(date +%F)"
bash "$HOME/.claude/skills/end-of-day-ai-retro/scripts/session-files.sh" list --agent pi --date "$(date +%F)"
bash "$HOME/.claude/skills/end-of-day-ai-retro/scripts/session-files.sh" list --agent cursor --date "$(date +%F)"
```

### 2. 次に代表セッションの詳細を見る

`retro` で上位に出たセッションは、少なくとも 3 件は `show` で冒頭・末尾・主要メッセージを確認する。いきなり大量に追わない。

```bash
bash "$HOME/.claude/skills/end-of-day-ai-retro/scripts/session-files.sh" show <session-file>
```

出力量を増やしたい場合だけ行数を広げる。

```bash
bash "$HOME/.claude/skills/end-of-day-ai-retro/scripts/session-files.sh" show <session-file> --lines 80
```

### 3. 振り返りへ落とし込む

セッションファイルを見たら、単なる「長かった」ではなく、次の形に変換する。

- どの agent / session file で詰まったか
- そのセッションでユーザーは何を要求していたか
- agent はどの判断、tool call、確認質問、出力で止まったか
- 何がボトルネックだったか
- それは skill / rules / prompt / hook / 運用のどこで改善できるか

## 観察対象

- 同じ指示を何度も手で足した場面
- 毎回迷ったコマンド、承認、sandbox、作業ディレクトリ指定
- 情報不足で作業が止まった場面
- 逆に、rules・skill・テンプレートで速く進んだ場面
- セッション切り替え、通知、resume、worktree 運用で詰まった場面
- レビュー品質、計画品質、出力フォーマットの揺れ
- セッションファイル上で大きい出力、長い往復、tool error、同じ質問が偏った session
- Codex / Claude / Pi agent / Cursor の使い分けで、別エージェントに寄せるべきだった作業

## 改善候補の切り分け

### Claude Code に寄せる改善

- slash command / custom command に切り出すべきか
- `CLAUDE.md` や repo ローカル instruction に昇格すべきか
- 既存 skill を増強すべきか、新規 skill を作るべきか
- 長時間作業を tmux / delegate / worktree に逃がすべきか
- 通知や hook による補助が必要か

### Codex に寄せる改善

- `~/.codex/config.toml` を変えるべきか
- `~/.codex/rules/*.rules` に昇格すべき運用知識か
- 繰り返し使う作業を skill 化すべきか
- 開始ディレクトリ、`codex exec` の使い分け、履歴保持設定を見直すべきか
- 通知、ログ保存、外部ツール連携を見直すべきか

### Pi agent に寄せる改善

- `~/.pi/agent/settings.json` やモデル選択を変えるべきか
- delegate する作業粒度や完了条件を明文化すべきか
- 長時間・反復作業を Pi agent に逃がすべきか
- Pi agent 側の skill やセッション保存運用を増強すべきか

### Cursor に寄せる改善

- project rules や agent prompt に昇格すべきか
- IDE 内での編集・調査に寄せるべき作業だったか
- `~/.cursor/projects/.../rules` や workspace 設定を見直すべきか
- agent transcript が追いにくいなら、セッション命名やプロジェクト分割を見直すべきか

## 判断基準

- その場の一発プロンプトで十分なら、設定化しない
- 週に複数回起きるなら、設定・rules・skill 化を優先する
- 失敗コストが高いなら、自由文より rules / 手順化を優先する
- 汎用化できない個別事情は、project doc やタスク文脈に残し、グローバル設定に混ぜない
- まず小さい変更を選び、翌日に効くものから入れる

## 出力要件

必ず次の形式で返す。

1. 今日うまくいった運用
2. 今日つまずいた運用
3. セッションファイルで確認した事実
4. 恒久化すべき変更候補
5. 明日入れる変更
6. 変更後の確認方法

変更候補は最大3件とし、少なくとも以下を含める。

- 対象: `Claude Code` / `Codex` / `Pi agent` / `Cursor` / `複数`
- 変更場所: 例 `~/.codex/config.toml`, `~/.codex/rules/*.rules`, `.claude/skills/...`, `CLAUDE.md`, `~/.pi/agent/settings.json`, `~/.cursor/projects/.../rules`
- 変更内容: 1-2文
- 期待効果: 1文
- 観察根拠: session / trace / ticketの秘匿済み識別子
- リスク: 1文
- 優先度: P1/P2/P3
- 検証方法: 1文

## 禁止事項

- 変更案を大量に列挙して優先順位をぼかさない
- 観察根拠なしに設定を増やさない
- セキュリティや破壊的操作に関する緩和提案を、根拠なく推奨しない
- repo ローカルで済むものをグローバル設定に広げない
- セッションファイル 1 件だけの単発異常で恒久対応を決めない
- raw prompt/response、secret、token、個人情報、cluster固有値をpublic dotfilesや提案へ転載しない
- 日次runからrepo、agent設定、skill、rules、clusterを自動変更しない
