#!/usr/bin/env bash
set -euo pipefail

runner="$(cd "$(dirname "$0")" && pwd)/run-delegate.sh"
formatter="$(cd "$(dirname "$0")" && pwd)/format-stream.sh"
state_root="$(mktemp -d)"
mock_bin="$state_root/bin"
notify_log="$state_root/notifications.log"
mkdir -p "$mock_bin"
trap 'rm -rf "$state_root"' EXIT

printf '%s\n' '#!/usr/bin/env sh' 'printf "%s\\n" "$*" >> "$AI_DELEGATE_NOTIFY_LOG"' > "$mock_bin/osascript"
chmod +x "$mock_bin/osascript"
export PATH="$mock_bin:$PATH"
export AI_DELEGATE_NOTIFY_LOG="$notify_log"

"$runner" --state-root "$state_root" --session-id succeeds --working-directory /tmp -- sh -c 'printf success-output'
test "$(cat "$state_root/succeeds/status")" = success
test "$(cat "$state_root/succeeds/exit_code")" = 0
grep -q success-output "$state_root/succeeds/output.log"
grep -q 'AI delegate completed' "$notify_log"

if "$runner" --state-root "$state_root" --session-id fails --working-directory /tmp -- sh -c 'printf failure-output; exit 7'; then
  echo 'expected failing delegate command to fail' >&2
  exit 1
fi
test "$(cat "$state_root/fails/status")" = failed
test "$(cat "$state_root/fails/exit_code")" = 7
grep -q failure-output "$state_root/fails/output.log"
grep -q 'AI delegate failed' "$notify_log"

claude_tool_line='{"type":"stream_event","event":{"type":"content_block_start","index":0,"content_block":{"type":"tool_use","id":"toolu_1","name":"Bash","input":{"command":"echo hi","description":"say hi"}}}}'
claude_result_line='{"type":"user","message":{"content":[{"type":"tool_result","content":"hi\n","is_error":false}]}}'
claude_final_line='{"type":"result","result":"done","subtype":"success"}'

formatted="$(
  {
    printf '%s\n' "$claude_tool_line"
    printf '%s\n' "$claude_result_line"
    printf '%s\n' "$claude_final_line"
  } | "$formatter" claude
)"
grep -q '\[tool\] Bash echo hi' <<< "$formatted"
grep -q '\[result\] hi' <<< "$formatted"
grep -q '\[final\] done' <<< "$formatted"

cursor_tool_start='{"type":"tool_call","subtype":"started","tool_call":{"shellToolCall":{"args":{"command":"echo hi","description":"say hi"}}}}'
cursor_tool_done='{"type":"tool_call","subtype":"completed","tool_call":{"shellToolCall":{"result":{"success":{"stdout":"hi\n"}}}}}'
cursor_final='{"type":"result","subtype":"success","result":"all good"}'

formatted="$(
  {
    printf '%s\n' "$cursor_tool_start"
    printf '%s\n' "$cursor_tool_done"
    printf '%s\n' "$cursor_final"
  } | "$formatter" cursor
)"
grep -q '\[tool\] Shell echo hi' <<< "$formatted"
grep -q '\[result\] hi' <<< "$formatted"
grep -q '\[final\] all good' <<< "$formatted"

non_json='plain log line'
formatted="$(printf '%s\n' "$non_json" | "$formatter" claude)"
test "$formatted" = "$non_json"

if command -v tmux >/dev/null 2>&1 && tmux info >/dev/null 2>&1; then
  channel="ai-delegate-test-$$-$(date +%s%N)"
  (
    tmux wait-for "$channel"
    printf done > "$state_root/wait-for.done"
  ) &
  waiter_pid=$!
  sleep 0.5
  if [ -f "$state_root/wait-for.done" ]; then
    echo 'tmux wait-for waiter unblocked before signal' >&2
    kill "$waiter_pid" 2>/dev/null || true
    exit 1
  fi
  tmux wait-for -S "$channel"
  wait "$waiter_pid"
  test "$(cat "$state_root/wait-for.done")" = done
fi
