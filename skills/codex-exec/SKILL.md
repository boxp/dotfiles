---
name: codex-exec
description: codex execでコード実装・修正・分析タスクを委譲。「codexで実装」「codexに任せて」「codex execで実行」「コード修正をcodexに委譲」時に使用
argument-hint: "[options] <prompt-or-file>"
allowed-tools: "Bash, Read, Grep, Glob, Write"
---

# Codex CLIによるタスク委譲（codex exec）

codex execコマンドを使って、コードの実装・修正・分析などのタスクを委譲します。

## 使用方法

### 基本的な実行
```bash
codex exec "<タスクの説明>"
```

### 作業ディレクトリを指定して実行
```bash
codex exec -C <directory> "<タスクの説明>"
```

### Git管理外のディレクトリで実行
```bash
codex exec -C <directory> --skip-git-repo-check "<タスクの説明>"
```

### 自動実行モード（承認プロンプトなし、ネットワーク許可）
```bash
codex exec -s danger-full-access "<タスクの説明>"
```

### モデルを指定して実行
```bash
codex exec -m <model-name> "<タスクの説明>"
```

## 引数

$ARGUMENTS

- `<prompt-or-file>`: タスクの説明テキスト、またはプロンプトファイルのパス
  - 直接テキスト: `codex exec "ここにタスク説明"`
  - ファイルから読み込み: `cat <prompt-file> | codex exec -`

### オプション
- `-C <directory>`: 作業ディレクトリを指定
- `--skip-git-repo-check`: Gitリポジトリ外での実行を許可
- `-m <model>`: 使用モデルを指定
- `-s danger-full-access`: 自動実行モード（sandbox無効、ネットワーク許可）
- `--add-dir <DIR>`: 追加の書き込み可能ディレクトリを指定
- `-i <image>`: 画像ファイルを添付（スクリーンショットベースの実装など）
- `-o <file>`: 最終メッセージをファイルに出力
- `--ephemeral`: セッション履歴を保存しない

## プロンプトの書き方

効果的なプロンプトには以下を含めること:

1. **目的**: 何を実装・修正するか
2. **対象ファイル**: 変更すべきファイルやディレクトリ
3. **具体的な手順**: 期待する変更の詳細
4. **制約事項**: コーディング規約、既存パターンの遵守など

### 長いプロンプトの場合

プロンプトが長くなる場合はファイルに書き出してstdinから渡す:

```bash
cat /tmp/task-prompt.txt | codex exec -C <directory> -
```

## 実行例

### 新機能の実装
```bash
codex exec -C ~/project "src/utils/に新しいヘルパー関数validateEmail()を実装してください。
既存のsrc/utils/validators.tsのパターンに従い、テストも追加してください。"
```

### バグ修正
```bash
codex exec -C ~/project "issue #123のバグを修正してください。
src/components/UserList.tsxでページネーションが正しく動作しない問題です。
修正後にテストが通ることを確認してください。"
```

### リファクタリング
```bash
codex exec -C ~/project -s danger-full-access "src/legacy/配下のコードをTypeScriptに変換してください。
既存のsrc/modern/のコーディングスタイルに合わせてください。"
```

### worktreeとの連携
```bash
# worktreeスキルでブランチを作成後、worktreeのパスを指定して実行
codex exec -C $(gwq get feature/new-feature) "READMEにインストール手順を追加してください"
```

### Git管理外のファイル操作
```bash
codex exec -C ~/.config --skip-git-repo-check "neovim設定をLua形式にマイグレーションしてください"
```

### スクリーンショットベースの実装
```bash
codex exec -C ~/project -i mockup.png "添付のモックアップ画像に基づいてReactコンポーネントを実装してください"
```

### 結果をファイルに出力
```bash
codex exec -C ~/project -o /tmp/result.md "src/配下のアーキテクチャを分析して改善案を提案してください"
```

## 注意事項

- デフォルトではサンドボックス内で実行される（ファイル変更はworkspace内に限定）
- `-s danger-full-access`はサンドボックスを無効化しネットワークも許可する。`--full-auto`（workspace-write）はネットワーク遮断されるため`uv run`等が失敗する
- 自動実行モードでは承認なしで実行されるため、意図しない変更に注意
- Gitリポジトリ外で実行する場合は`--skip-git-repo-check`が必須
- 長時間かかるタスクの場合、`claude-delegate`スキルでtmuxセッションに委譲することも検討
- プロンプト内にシェル特殊文字（`$`, `` ` ``, `!`等）が含まれる場合はシングルクォートで囲むか適切にエスケープすること
