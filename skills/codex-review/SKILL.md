---
name: codex-review
description: Git管理下のコードをcodex CLIでレビュー。「codexでレビュー」「PRをレビュー」「変更をレビュー」時に使用
argument-hint: "[--uncommitted | --base <branch> | --commit <sha>]"
---

# Codex CLIによるコードレビュー（Git管理下）

codex reviewコマンドを使って、Git管理下の変更をレビューします。

## 使用方法

### 未コミットの変更をレビュー
```bash
codex review --uncommitted
```

### 特定ブランチとの差分をレビュー
```bash
codex review --base main
```

### 特定コミットの変更をレビュー
```bash
codex review --commit <sha>
```

### カスタム指示付きレビュー（codex execを使用）
`codex review`ではオプションとプロンプトを同時に指定できないため、
カスタムプロンプトが必要な場合は`codex exec`を使用します。

```bash
# 特定のファイルを読んでレビュー
codex exec "src/foo.cljファイルを読んで、セキュリティの観点からレビューしてください"

# 問題の状況を説明してコードを分析
codex exec "以下の問題が発生しています: [問題の説明]

関連するファイルを読んで原因を分析してください。"
```

## 引数

$ARGUMENTS

- `--uncommitted`: ステージ済み・未ステージ・未追跡の変更をレビュー
- `--base <branch>`: 指定ブランチとの差分をレビュー
- `--commit <sha>`: 特定コミットの変更をレビュー

## 注意事項

- Git管理下のディレクトリで実行してください
- `codex review`のオプション（--uncommitted等）とカスタムプロンプトは同時に使用できません
- カスタムプロンプトが必要な場合は`codex exec`を使用してください
- レビュー結果はCodexのモデルによって生成されます
