# end-of-day-ai-retro スキル作成計画

## Context

一日の終わりに、その日の Claude Code / Codex のセッションを振り返り、翌日以降の設定改善につなげる skill を追加する。背景として、Confluence の `2026-05-27 僕のAIかんきょう！！共有会` では `session-retro-codex` のような運用例が共有されており、`history.persistence = "save-all"` を前提にセッション履歴から改善案を出す流れが示されている。

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

### 3. 変更: `setup.sh`

`ENABLED_CLAUDE_SKILLS` に `end-of-day-ai-retro` を追加し、`setup.sh` 実行時に `~/.claude/skills` と `~/.codex/skills` へ symlink されるようにする。

## 変更しないもの

- **補助スクリプト**: 今回は設定改善提案のワークフロー定義が中心のため不要
- **`CODEX_EXCLUDED_SKILLS`**: この skill は Codex 側でも使いたいため除外しない

## 検証方法

1. `quick_validate.py` で skill frontmatter と命名規則を検証
2. `generate_openai_yaml.py` で `agents/openai.yaml` を生成できることを確認
3. `setup.sh` の `ENABLED_CLAUDE_SKILLS` に追加されたことを確認
4. skill の文面が Claude/Codex 両方の設定改善フローとして自然かを目視確認
