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

### カスタム指示付きレビュー
```bash
codex review --uncommitted "セキュリティの観点から確認してください"
```

## 引数

$ARGUMENTS

- `--uncommitted`: ステージ済み・未ステージ・未追跡の変更をレビュー
- `--base <branch>`: 指定ブランチとの差分をレビュー
- `--commit <sha>`: 特定コミットの変更をレビュー
- カスタムプロンプト: レビューの観点を指定

## 注意事項

- Git管理下のディレクトリで実行してください
- レビュー結果はCodexのモデルによって生成されます
