# end-of-day-ai-retro / Langfuse retro 拡張計画

## Context

一日の終わりに、その日の Claude Code / Codex のセッションを振り返り、翌日以降の設定改善につなげる skill を追加する。さらに、ローカル Langfuse trace を直接見ながら、感覚ではなく trace を根拠に振り返れるようにする。

このリポジトリでは `.claude/skills/` 配下の skill を `setup.sh` で `~/.claude/skills/` と `~/.codex/skills/` に symlink する構成になっているため、repo 配下に skill を追加し、Claude/Codex の両方から使えるようにする。

## 変更対象ファイル

### 1. 新規作成: `.claude/skills/end-of-day-ai-retro/SKILL.md`

終業時のセッション振り返り skill を定義する。

- **name**: `end-of-day-ai-retro`
- **description**:
  `一日の Claude Code / Codex セッションを振り返り、設定・rules・skills・フック・運用を改善する。終業時の振り返り、session retro、daily AI review、Claude/Codex の設定見直し、rules 改善、プロンプト改善をしたい時に使用`

内容:
- 振り返りの目的と期待アウトプット
- 事前確認項目
- セッションから観察すべき観点
- Claude Code 向け改善観点
- Codex 向け改善観点
- 変更提案の優先順位付け
- 最終出力テンプレート

### 2. 新規作成: `.claude/skills/end-of-day-ai-retro/references/retro-checklist.md`

SKILL 本文を軽く保つため、詳細な観点と出力テンプレートを reference に分離する。

内容:
- セッション観察チェックリスト
- 改善施策の分類
- 変更提案の書き方
- 翌日の検証項目テンプレート

### 3. 新規作成: `.claude/skills/end-of-day-ai-retro/references/langfuse-retro.md`

Langfuse trace を読む観点と、`list/get` から retro に落とすための見方を分離して持つ。

### 4. 新規作成: `.claude/skills/end-of-day-ai-retro/scripts/langfuse-traces.sh`

ローカル Langfuse API を叩いて trace 一覧・詳細を取る補助スクリプト。`~/.codex/langfuse.json` を自動で読む。

### 5. 変更: `~/.codex/rules/default.rules`

探索・調査系の長い turn を分割するための運用ルールを追加する。

### 6. 変更: `langfuse-traces.sh`

plugin は編集せず、retro 出力側で trace の input/output/name から作業種別を推定して見える化する。

## 検証方法

1. `langfuse-traces.sh --help`, `list`, `retro`, `get` が動くこと
2. `~/.codex/langfuse.json` だけで local Langfuse に疎通できること
3. tracing plugin の build が通ること
4. `retro` 出力で `workType` が見えること
5. `~/.codex/rules/default.rules` の追加ルールが自然かを目視確認
