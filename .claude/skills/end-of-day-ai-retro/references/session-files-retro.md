# セッションファイルを使った振り返り

ローカルセッションファイルは「今日はなんとなく詰まった」を、agent と session file 単位の観察に落とせる。終業時の振り返りでは、感想ではなくセッションファイルを根拠に改善案を作る。

## 対象

- Codex: `~/.codex/sessions/**/*.jsonl`
- Claude Code: `~/.claude/projects/**/*.jsonl`
- Pi agent: `~/.pi/agent/sessions/**/*.jsonl`
- Cursor: `~/.cursor/projects/**/agent-transcripts/*.jsonl`

## 見る順番

1. `scripts/session-files.sh retro --date "$(date +%F)" --limit 40 --top 12` で今日の候補を出す
2. サイズや行数が大きいもの、同じ作業名が重複しているもの、agent をまたいで似た作業をしているものを選ぶ
3. 上位 3 件は `show <session-file>` で冒頭・末尾・主要メッセージを見る
4. 名前、時刻、cwd、project path から、どの作業文脈だったかを結びつける
5. 改善できる場所が skill / rules / prompt / hook / 運用のどれかに分類する

## 確認する観点

- `file`: 実際に確認したセッションファイル
- `agent`: Codex / Claude Code / Pi agent / Cursor のどれか
- `cwd` / project path: 作業 repo や worktree が意図通りか
- `first user message`: 依頼の入口が明確か
- `tool error`: 同じ tool call が失敗していないか
- `approval` / `permission`: 承認や権限で止まっていないか
- `final response`: 完了条件を満たしているか、途中で終わっていないか
- `handoff`: 別 agent に委譲すべき作業を抱え込んでいないか

## 改善へ変換する例

- 同じ前提を毎回貼っている:
  - `AGENTS.md`、`CLAUDE.md`、`~/.codex/rules/*.rules`、Cursor project rules へ昇格する
- 同じ tool error が複数 session で出る:
  - skill の事前確認、fallback、検証コマンドを追加する
- Codex と Claude で同じ探索を繰り返している:
  - どちらを一次調査に使うか、委譲条件を rules 化する
- Pi agent が長時間作業に効いている:
  - delegate 用 skill や完了報告テンプレートを強化する
- Cursor transcript が追いにくい:
  - project rules、作業単位、ファイル命名、workspace 分割を見直す

## 注意

- セッションファイル 1 件だけで結論を出さない
- 大きいファイルを丸ごと読む前に、まず一覧と要約で候補を絞る
- private な入力、認証情報、社内情報を回答に不要に転記しない
- repo ローカルの摩擦をグローバル設定へ広げない
