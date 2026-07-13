---
name: claude-delegate
description: 別の tmux ペイン（既定）または detached セッション（fallback）で Claude Code にタスクを委譲する。
argument-hint: <session-name> <working-directory> <prompt-or-file>
---

# Claude Code タスク委譲

tmux の背景 pane（tmux 外では detached session）で Claude を非対話・一回実行する。委任元は進捗をポーリングしない。終了時の macOS 通知と状態ファイルで結果を受け取り、pane は最終出力確認のため残す。

## 引数とプロンプト

- `$ARGUMENTS`: `<session-name> <working-directory> <prompt-or-file>`
- 直接テキストは `/tmp/<session-name>-prompt.txt` に書き出し、ファイルならそのまま使う。
- プロンプトには背景、現状、具体的な作業、注意事項を含める。

## tmux ターゲットを作る

tmux 内では右側 50% の背景 pane、tmux 外では同名衝突を確認した detached session を使う。

```bash
if [ -n "${TMUX:-}" ] && [ -n "${TMUX_PANE:-}" ]; then
  PANE_ID="$(tmux split-window -h -d -p 50 -c <working-directory> -P -F '#{pane_id}')"
  TARGET="$PANE_ID"
else
  tmux has-session -t <session-name> 2>/dev/null && exit 1
  tmux new-session -d -s <session-name> -c <working-directory>
  TARGET="<session-name>"
fi
```

## 共通ランナーで起動する

信頼済みの対象 worktree に限り、確認待ちを作らない `--dangerously-skip-permissions` を明示する。プロンプトをシェル展開せず標準入力で渡す。

```bash
RUNNER="<dotfiles>/.claude/skills/claude-delegate/scripts/run-delegate.sh"
COMMAND="$(printf '%q ' "$RUNNER" --session-id <session-name> --working-directory <working-directory> -- claude --print --dangerously-skip-permissions) < <(cat <prompt-file>)"
tmux send-keys -t "$TARGET" "$COMMAND" Enter
```

`claude --print "$(cat file)"` は使わない。

## 終了通知と必要時の確認

ランナーは `/tmp/ai-delegate/<session-name>/` に `started_at`、`finished_at`、`exit_code`、`status`（`success` / `failed`）、`output.log` を保存し、pane の `@ai_delegate_session_id`、`@ai_delegate_state_dir`、`@ai_delegate_status` にも設定する。終了時には macOS 通知を試行する。通知権限がない場合でも状態ファイルは残る。

進捗目的の定期的な `capture-pane` は行わない。必要時だけ次を使う。

```bash
cat /tmp/ai-delegate/<session-name>/status
cat /tmp/ai-delegate/<session-name>/exit_code
tail -80 /tmp/ai-delegate/<session-name>/output.log
tmux capture-pane -t "$TARGET" -p | tail -80
```

## クリーンアップ

完了・失敗後も pane / session は自動で閉じない。最終出力を確認後、不要なら明示的に閉じる。

```bash
tmux kill-pane -t "$PANE_ID"       # pane ルート
tmux kill-session -t <session-name> # fallback ルート
```

fallback ルートでは同じ `session-name` を二重起動しない。pane ルートでは元の pane にフォーカスが残る。
