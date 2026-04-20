---
name: worktree
description: gwq・tmuxを使ったworktree操作（作成・削除・開発サーバー起動・状態確認）。「worktreeを作成」「worktreeを削除」「開発サーバーを立ち上げたい」「worktreeの状況を見たい」「新しいブランチで作業」「feature branchを切りたい」「バックグラウンドでプロセス実行」「実行中プロセスを確認」「作業を終了」「gwq」時に使用
argument-hint: <subcommand> [args...] (create|cleanup|dev|status)
---

# Worktree管理

gwq・tmuxを使ったworktreeのライフサイクル全体を管理します。

## サブコマンド

`$ARGUMENTS` の先頭でサブコマンドを指定します。省略時はコンテキストから適切な操作を判断してください。

---

## create - Worktree作成

新しいworktreeを作成します。

### 引数
- `create <branch-name>`

### 手順

1. 既存ブランチからworktreeを作成する場合:
   ```bash
   git fetch origin <branch-name>
   gwq add <branch-name>
   ```

2. 新規ブランチを作成してworktreeを作成する場合:
   ```bash
   gwq add -b <branch-name>
   ```

3. 作成後、worktreeのパスを取得して移動可能:
   ```bash
   cd $(gwq get <branch-name>)
   ```

4. 作成されたworktreeの確認:
   ```bash
   gwq list
   ```

### オプション
- インタラクティブ選択: `gwq add -i`
- 作成後そのまま移動: `gwq add -s <branch>`

---

## cleanup - Worktreeクリーンアップ

作業完了後のworktreeとtmuxセッションを削除します。

### 引数
- `cleanup <worktree-pattern>`

### 手順

1. tmuxセッション終了:
   ```bash
   gwq tmux kill <pattern>
   ```

2. worktree削除（ブランチは残す）:
   ```bash
   gwq remove <pattern>
   ```

3. worktreeとブランチを一緒に削除:
   ```bash
   gwq remove -b <pattern>
   ```

4. 不要なworktree情報をクリーンアップ:
   ```bash
   gwq prune
   ```

### オプション
- 強制削除（未コミット変更があっても）: `gwq remove -f <pattern>`

### 注意
- 削除前に `gwq status` で変更がないか確認
- 重要な変更がある場合はコミットしてから削除
- **重要**: `gwq remove`は削除対象のworktreeディレクトリ内からは実行できない。メインリポジトリディレクトリに移動してから実行すること
  ```bash
  cd $(gwq get master)  # または cd ~/ghq/github.com/<owner>/<repo>
  gwq remove -b <pattern>
  ```

### 完全クリーンアップ例
```bash
# 1. セッション終了
gwq tmux kill feature/done

# 2. メインリポジトリに移動
cd $(gwq get master)

# 3. worktreeとブランチ削除
gwq remove -b feature/done

# 4. 孤立したworktree参照をクリーン
gwq prune

# 5. 最新のmainブランチに戻る
cd $(gwq get main || gwq get master)
git pull origin main || git pull origin master
```

---

## dev - 開発サーバー起動

gwq tmuxを使ってworktreeで長時間実行プロセスをバックグラウンド起動します。

### 引数
- `dev <worktree-pattern> <command>`
  - 例: `dev feature/new-feature "npm run dev"`

### 手順

1. worktreeでコマンドをtmuxセッションで起動:
   ```bash
   gwq tmux run -w <worktree-pattern> "<command>"
   ```

2. セッション一覧確認:
   ```bash
   gwq tmux list
   ```

3. セッションにアタッチ（ログ確認など）:
   ```bash
   gwq tmux attach <pattern>
   ```

### オプション
- カスタムセッションID: `gwq tmux run --id <name> "<command>"`
- アタッチしたまま実行: `gwq tmux run --no-detach "<command>"`
- 完了時自動削除: `gwq tmux run --auto-cleanup "<command>"`

### 例
```bash
# フロントエンド開発サーバー
gwq tmux run -w feature/ui "npm run dev"

# バックエンドサーバー
gwq tmux run -w feature/api "go run main.go"

# テスト監視
gwq tmux run -w feature/test "npm run test:watch"
```

---

## status - 状態確認

gwqを使ってworktreeとプロセスの状態を確認します。

### 手順

1. 現在のリポジトリのworktree一覧:
   ```bash
   gwq list -v
   ```

2. 全リポジトリのworktree一覧:
   ```bash
   gwq list -g
   ```

3. 全worktreeの状態（変更ファイルなど）:
   ```bash
   gwq status
   ```

4. 実行中プロセス情報付き:
   ```bash
   gwq status -g --show-processes
   ```

5. tmuxセッション一覧:
   ```bash
   gwq tmux list
   ```

### オプション
- 監視モード（自動更新）: `gwq status -w`
- 特定worktreeの詳細: `gwq get <pattern>`

### 出力例
```
gwq status -g --show-processes
────────────────────────────────────
repo: frontend
  feature/ui [modified: 3 files]
    └─ tmux: npm run dev (pid: 12345)

repo: backend
  feature/api [clean]
    └─ tmux: go run main.go (pid: 12346)
```
