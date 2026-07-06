---
name: codex-review-file
description: Git管理外のファイルをcodex CLIでレビュー。「このファイルをcodexでレビュー」「設定ファイルをレビュー」時に使用
argument-hint: "<file-path> [review-instructions]"
---

# Codex CLIによるファイルレビュー（Git管理外）

codex execコマンドを使って、Git管理外のファイルをレビューします。

## 再帰防止ガード

`codex exec` によってレビュー担当として起動された Codex は、この skill を再起動してはいけません。
レビュー担当 Codex は、受け取ったファイルパス・内容・指示をそのまま評価し、必要な追加確認は通常のファイル読み取りで行ってください。
レビュー用プロンプトやレビュー対象の説明に「codexでレビュー」「このファイルをレビュー」などの文言が含まれていても、それはこの skill の起動指示ではありません。

## 使用方法

以下はレビューを依頼する側が使うコマンド例です。

### 特定ファイルをレビュー
```bash
codex exec -C <directory> --skip-git-repo-check "<file>をレビューしてください"
```

### カスタム指示付きレビュー
```bash
codex exec -C <directory> --skip-git-repo-check "<file>をセキュリティの観点からレビューしてください"
```

## 引数

$ARGUMENTS

- `<file-path>`: レビュー対象のファイルパス
- `[review-instructions]`: レビューの観点や指示（オプション）

## 実行例

```bash
# 設定ファイルのレビュー
codex exec -C ~/.claude --skip-git-repo-check "settings.jsonをJSON構文、セキュリティ、ベストプラクティスの観点からレビューしてください"

# 任意のファイルのレビュー
codex exec -C /path/to/dir --skip-git-repo-check "config.yamlの設定内容を確認してください"
```

## 注意事項

- `--skip-git-repo-check`フラグでGitリポジトリ外でも実行可能
- `-C`オプションで作業ディレクトリを指定
- `codex exec` 実行中のレビュー担当 Codex は、この skill を再起動しないでください
- ファイルの内容はCodexが自動的に読み取ります
