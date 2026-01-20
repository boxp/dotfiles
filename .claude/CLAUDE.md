# 複数リポジトリ横断開発のワークフロー

複数のリポジトリを横断して開発する必要がある場合は、ghq・gwq・tmuxを組み合わせて新しいworktreeを立てて開発すること。

## ツール概要

### ghq - リポジトリ管理

リモートリポジトリのクローンを統一的なディレクトリ構造で管理するツール。

```bash
# リポジトリの取得
ghq get <repository-url>
ghq get github.com/user/repo

# ローカルリポジトリ一覧
ghq list
ghq list -p  # フルパスで表示

# リポジトリのルートディレクトリ
ghq root
```

### gwq - Git Worktree管理

ghqのようにgit worktreeを直感的に管理するツール。

```bash
# worktree作成
gwq add <branch>                    # 既存ブランチからworktree作成
gwq add -b <branch>                 # 新規ブランチ作成と同時にworktree作成
gwq add -i                          # インタラクティブにブランチ選択
gwq add -s <branch>                 # 作成後そのディレクトリに移動

# worktree一覧
gwq list                            # 現在のリポジトリのworktree一覧
gwq list -g                         # 全リポジトリのworktree一覧
gwq list -v                         # 詳細情報付き

# worktreeパス取得
cd $(gwq get <pattern>)             # パターンにマッチするworktreeに移動

# worktree内でコマンド実行
gwq exec <pattern> -- <command>     # 指定worktreeでコマンド実行

# worktree状態確認
gwq status                          # 全worktreeの状態表示
gwq status -g                       # 全リポジトリのworktree状態
gwq status --show-processes         # 実行中プロセス情報も表示
gwq status -w                       # 監視モード（自動更新）

# worktree削除
gwq remove <pattern>                # worktree削除
gwq remove -b <pattern>             # worktreeとブランチを削除
gwq remove -f <pattern>             # 強制削除
```

### gwq tmux - 長時間プロセス管理

worktreeごとにtmuxセッションを管理し、長時間実行プロセスを永続化する。

```bash
# セッション一覧
gwq tmux list

# コマンドをtmuxセッション内で実行
gwq tmux run "<command>"                        # 新規セッションでコマンド実行
gwq tmux run -w <worktree> "<command>"          # 指定worktreeで実行
gwq tmux run --id <name> "<command>"            # カスタムID指定
gwq tmux run --no-detach "<command>"            # アタッチしたまま実行
gwq tmux run --auto-cleanup "<command>"         # 完了時に自動でセッション削除

# セッション操作
gwq tmux attach <pattern>           # セッションにアタッチ
gwq tmux kill <pattern>             # セッション終了
```

### tmux基本操作

```bash
# セッション管理
tmux new -s <name>                  # 新規セッション作成
tmux attach -t <name>               # セッションにアタッチ
tmux ls                             # セッション一覧
tmux kill-session -t <name>         # セッション終了

## 推奨ワークフロー

### 1. 新機能開発の開始

```bash
# 対象リポジトリに移動
cd $(ghq get -p <repo>)

# 機能ブランチのworktreeを作成
gwq add -b feature/new-feature

# 開発サーバーをtmuxで起動
gwq tmux run -w feature/new-feature "npm run dev"
```

### 2. 複数リポジトリでの並行作業

```bash
# 各リポジトリでworktreeを作成
cd $(ghq get -p frontend-repo) && gwq add -b feature/api-integration
cd $(ghq get -p backend-repo) && gwq add -b feature/new-endpoint

# 各worktreeでプロセス起動
gwq tmux run -w feature/api-integration "npm run dev"
gwq tmux run -w feature/new-endpoint "go run main.go"

# 状態確認
gwq status -g --show-processes
```

### 3. 作業完了後のクリーンアップ

```bash
# tmuxセッション終了
gwq tmux kill <pattern>

# worktreeとブランチを削除
gwq remove -b <pattern>

# 不要なworktree情報をクリーンアップ
gwq prune
```
