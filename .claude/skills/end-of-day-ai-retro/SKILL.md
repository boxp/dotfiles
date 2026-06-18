---
name: end-of-day-ai-retro
description: 一日の Claude Code / Codex セッションを振り返り、設定・rules・skills・フック・運用を改善する。終業時の振り返り、session retro、daily AI review、Claude/Codex の設定見直し、rules 改善、プロンプト改善をしたい時に使用
---

# 終業時 AI リフレクション

一日の終わりに、その日の Claude Code / Codex の使い方を棚卸しし、翌日から効く設定改善に落とし込む。

目的は感想を書くことではなく、「何が詰まり、何が効き、何を設定へ昇格させるべきか」を抽出し、`~/.claude` や `~/.codex` に対する具体的な変更案まで整理すること。

## 進め方

1. 今日の対象セッションを確定する
2. セッションの摩擦と成功パターンを集める
3. Claude Code / Codex のどちらに寄せる改善かを分ける
4. 一時的なプロンプト工夫ではなく、設定・skill・rules・hook に昇格させる候補を選ぶ
5. 変更案、期待効果、検証方法を短くまとめる

詳細な観点と出力テンプレートは `references/retro-checklist.md` を読む。

## 事前確認

- `Codex` の履歴を使うなら `~/.codex/config.toml` で次を確認する
  ```toml
  [history]
  persistence = "save-all"
  ```
- `Claude Code` 側も、セッション履歴や通知フックを見返せる構成になっているか確認する
- repo 内 skill を改善候補に含める場合は、既存の `.claude/skills/` と `setup.sh` の有効化リストを確認する
- 単発の作業ミスではなく、再発しそうな摩擦を優先する

## 観察対象

- 同じ指示を何度も手で足した場面
- 毎回迷ったコマンド、承認、sandbox、作業ディレクトリ指定
- 情報不足で作業が止まった場面
- 逆に、rules・skill・テンプレートで速く進んだ場面
- セッション切り替え、通知、resume、worktree 運用で詰まった場面
- レビュー品質、計画品質、出力フォーマットの揺れ

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
3. 恒久化すべき変更候補
4. 明日入れる変更
5. 変更後の確認方法

変更候補ごとに、少なくとも以下を含める。

- 対象: `Claude Code` / `Codex` / `両方`
- 変更場所: 例 `~/.codex/config.toml`, `~/.codex/rules/*.rules`, `.claude/skills/...`, `CLAUDE.md`
- 変更内容: 1-2文
- 期待効果: 1文
- 検証方法: 1文

## 禁止事項

- 変更案を大量に列挙して優先順位をぼかさない
- 観察根拠なしに設定を増やさない
- セキュリティや破壊的操作に関する緩和提案を、根拠なく推奨しない
- repo ローカルで済むものをグローバル設定に広げない

