# pi agent goal harness

## 目的

pi agent で Codex `/goal` 相当の goal harness を使えるようにする。

## 実装方針

- dotfiles の `.pi/agent/extensions/goal-harness.ts` に pi extension として実装する。
- `~/.pi/agent/extensions/goal-harness.ts` に配置して、現在の pi agent から即時利用できるようにする。
- `/goal <objective>`, `/goal resume`, `/goal status`, `/goal clear` を提供する。
- `get_goal`, `create_goal`, `update_goal` tool を提供する。
- goal state は `pi.appendEntry("goal-harness-state", state)` で session branch に append-only 保存する。
- continuation context は hidden custom message として注入する。
- complete / blocked は `update_goal` tool からのみ許可し、blocked は `consecutiveBlockedTurns >= 3` を必須にする。

## 検証

- pi extension として読み込めること。
- `/goal status` が model call なしで動くこと。
- `/goal <objective>` で state entry と hidden context entry が session JSONL に保存されること。
- registered command / tool の存在を確認できること。

