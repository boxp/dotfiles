# pi agent goal harness

## 目的

pi agent で Codex `/goal` 相当の goal harness を使えるようにする。

## 実装方針

- dotfiles の `.pi/agent/extensions/goal-harness.ts` に pi extension として実装する。
- `setup.sh` で `~/.pi/agent/extensions/goal-harness.ts` を dotfiles の実装へ symlink し、現在の pi agent から即時利用できるようにする。
- 既存の同名ファイルは repo 版と同一の場合だけ symlink に置き換え、ローカル差分がある場合は上書きしない。
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
- `./setup.sh` 実行後に `~/.pi/agent/extensions/goal-harness.ts` が dotfiles 配下を指す symlink になること。
