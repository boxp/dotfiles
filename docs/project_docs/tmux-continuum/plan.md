# tmux-continuum導入による自動保存・自動復元の設定

## Context

現在、tmux-resurrectはTPMプラグインとして導入済みだが、手動で`prefix + Ctrl-s`(保存)と`prefix + Ctrl-r`(復元)を実行する必要がある。tmux-continuumを追加することで、セッションの自動保存と、tmuxサーバー起動時の自動復元を実現する。

また、Claude Code CLIのセッション復元もサポートするため、tmux-resurrectのPR #558（coding-agent-session-restore）を含むフォークを使用する。

## 変更対象ファイル

- `.tmux.conf` — tmux-continuumプラグインと設定の追加、resurrectのフォーク切り替え

## 変更内容

### `.tmux.conf` への変更

1. tmux-resurrectをPR #558対応のフォークに切り替え:

```tmux
# PR #558 (coding-agent-session-restore) を含むフォークを使用
# Claude Code/Codex CLIの自動セッション復元に対応
# マージ後は 'tmux-plugins/tmux-resurrect' に戻すこと
set -g @plugin 'thallada/tmux-resurrect#coding-agent-session-restore'
```

2. tmux-continuumプラグインと関連設定を追加:

```tmux
set -g @plugin 'tmux-plugins/tmux-continuum'

# resurrect: ペインの内容も保存
set -g @resurrect-capture-pane-contents 'on'

# continuum: 自動保存間隔（分） デフォルト15分
set -g @continuum-save-interval '15'

# continuum: tmuxサーバー起動時に自動復元
set -g @continuum-restore 'on'
```

**注意:** `tmux-continuum` は `status-right` に自動保存用のコマンドを埋め込むため、`status-right` の設定を確定した後、かつ `run '~/.tmux/plugins/tpm/tpm'` 行より前に配置すること。`run` 後に `status-right` を上書きすると自動保存が動かなくなる。

### Claude Code セッション復元の仕組み

PR #558により、tmux-resurrectは以下の動作を行う:

- `claude` プロセスをデフォルトの復元対象プロセスリストに追加
- `claude_session.sh` ストラテジーにより、復元時に `--continue` フラグを自動付与
- 既に `--continue` や `--resume` が含まれるコマンドはそのまま保持
- tmux-resurrectがペインの作業ディレクトリも復元するため、正しいディレクトリで `--continue` が実行される

### PR #558 マージ後の対応

PR #558が本家tmux-resurrectにマージされた後は、以下の行を元に戻す:

```tmux
# フォーク
set -g @plugin 'thallada/tmux-resurrect#coding-agent-session-restore'
# ↓ 本家に戻す
set -g @plugin 'tmux-plugins/tmux-resurrect'
```

## 適用後の手順

1. tmux内で `prefix + I`（大文字のI）を実行してTPMでプラグインをインストール
2. tmuxを再起動して自動復元が動作することを確認

## 検証方法

1. `.tmux.conf`の変更をsource: `tmux source-file ~/.tmux.conf`
2. `prefix + I` でtmux-continuumおよびフォーク版tmux-resurrectをインストール
3. 適当なウィンドウ・ペイン構成を作り、Claude Codeも起動した状態で、15分待つか `prefix + Ctrl-s` で手動保存
4. tmuxサーバーを終了 (`tmux kill-server`) してから再起動し、セッションおよびClaude Codeセッションが自動復元されることを確認

## 参考

- [tmux-resurrect PR #558](https://github.com/tmux-plugins/tmux-resurrect/pull/558) - Claude Code / Codex CLIセッション復元対応
