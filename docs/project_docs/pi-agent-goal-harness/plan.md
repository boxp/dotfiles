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
- active goal がある通常 prompt では `before_agent_start` で continuation context を注入する。
- `agent_end` 後も active goal が残っている場合は hidden follow-up message を queue し、次 turn で goal completion audit を実行させる。
- `update_goal complete/blocked` 後の same agent lifecycle では in-memory terminal state を正とし、agent_end で古い branch state に巻き戻さない。
- complete / blocked は `update_goal` tool からのみ許可し、blocked は `consecutiveBlockedTurns >= 3` を必須にする。

## 検証

- pi extension として読み込めること。
- `/goal status` が model call なしで動くこと。
- `/goal <objective>` で state entry と hidden context entry が session JSONL に保存されること。
- 1 turn 後に active goal が残っている場合、follow-up audit turn が queue されること。
- follow-up audit turn で goal が complete / blocked に遷移した場合、それ以上の follow-up が queue されないこと。
- `update_goal complete` 後に `agent_end` が発火しても追加 follow-up が queue されないこと。
- registered command / tool の存在を確認できること。
- `./setup.sh` 実行後に `~/.pi/agent/extensions/goal-harness.ts` が dotfiles 配下を指す symlink になること。
