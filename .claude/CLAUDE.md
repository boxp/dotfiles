# 複数リポジトリ横断開発

複数リポジトリで開発する場合は、ghq・gwq・tmuxを使ったworktreeワークフローを利用。

## Skills

- `/worktree-create <branch>` - 新しいworktree作成
- `/worktree-dev <worktree> <command>` - tmuxで開発サーバー起動
- `/worktree-status` - worktree・プロセス状態確認
- `/worktree-cleanup <pattern>` - worktree・セッション削除
- `/multi-repo-dev` - 複数リポジトリ並行開発ガイド
