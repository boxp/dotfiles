# tmux-continuum導入による自動保存・自動復元の設定

## Context

現在、tmux-resurrectはTPMプラグインとして導入済みだが、手動で`prefix + Ctrl-s`(保存)と`prefix + Ctrl-r`(復元)を実行する必要がある。tmux-continuumを追加することで、セッションの自動保存と、tmuxサーバー起動時の自動復元を実現する。

## 変更対象ファイル

- `.tmux.conf` — tmux-continuumプラグインと設定の追加

## 変更内容

### `.tmux.conf` への追加

プラグインリストに`tmux-continuum`を追加し、設定を記述する:

```tmux
# 既存のresurrect行の直後に追加
set -g @plugin 'tmux-plugins/tmux-continuum'

# resurrect: ペインの内容も保存
set -g @resurrect-capture-pane-contents 'on'

# continuum: 自動保存間隔（分） デフォルト15分
set -g @continuum-save-interval '15'

# continuum: tmuxサーバー起動時に自動復元
set -g @continuum-restore 'on'
```

**注意:** `run '~/.tmux/plugins/tpm/tpm'` 行より前に配置すること。

## 適用後の手順

1. tmux内で `prefix + I`（大文字のI）を実行してTPMでプラグインをインストール
2. tmuxを再起動して自動復元が動作することを確認

## 検証方法

1. `.tmux.conf`の変更をsource: `tmux source-file ~/.tmux.conf`
2. `prefix + I` でtmux-continuumをインストール
3. 適当なウィンドウ・ペイン構成を作り、15分待つか `prefix + Ctrl-s` で手動保存
4. tmuxサーバーを終了 (`tmux kill-server`) してから再起動し、セッションが自動復元されることを確認
