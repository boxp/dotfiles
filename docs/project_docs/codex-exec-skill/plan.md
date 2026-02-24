# codex-exec スキル作成計画

## Context

現在、codex CLIのスキルとして `codex-review`（Git管理下のコードレビュー）と `codex-review-file`（Git管理外のファイルレビュー）が存在するが、コードの実装・修正・分析タスクを `codex exec` に委譲するスキルがない。このスキルを作成することで、Claude Codeから `codex exec` を使った実装タスクの委譲を体系的に行えるようにする。

## 変更対象ファイル

### 1. 新規作成: `.claude/skills/codex-exec/SKILL.md`

`codex exec` コマンドを使ったタスク委譲スキルを定義する。

- **name**: `codex-exec`（実装に限定せず汎用的な名前）
- **description**: `codex execでコード実装・修正・分析タスクを委譲。「codexで実装」「codexに任せて」「codex execで実行」「コード修正をcodexに委譲」時に使用`
- **argument-hint**: `[options] <prompt-or-file>`
- **allowed-tools**: `Bash, Read, Grep, Glob, Write`

内容:
- 基本的な使い方（`codex exec "prompt"`）
- 作業ディレクトリ指定（`-C`）、Git管理外対応（`--skip-git-repo-check`）
- 自動実行モード（`--full-auto`）、モデル指定（`-m`）
- 長いプロンプトのファイル渡し（`cat prompt.txt | codex exec -`）
- worktreeとの連携パターン
- 画像添付（`-i`）、出力ファイル（`-o`）
- 注意事項（サンドボックス、シェルエスケープ等）

### 2. 変更: `.claude/CLAUDE.md`

skillsリストに `codex-exec` を追加

### 変更不要なファイル

- **`.claude/settings.local.json`**: `Bash(codex exec:*)` と `Bash(codex:*)` は既に許可済み
- **`setup.sh`**: `.claude/skills/` 配下のスキルは自動的に `~/.codex/skills/` にシンボリックリンクされる
- **補助スクリプト**: `codex exec` は十分シンプルなCLIのため不要

## 検証方法

1. スキルが認識されるか確認: Claude Codeで `/codex-exec` が補完されることを確認
2. 基本動作確認: `codex exec "echo hello world"` のような簡単なタスクで実行できることを確認
3. `-C` オプション確認: 作業ディレクトリ指定で正しく動作するか確認
