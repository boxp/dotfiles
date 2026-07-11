# Codex Terra Worker の永続化計画

## 目的

検証済みの `~/.codex/agents/terra_worker.toml` を `boxp/dotfiles` の source of truth として管理し、`setup.sh` 実行後に同じ定義を `~/.codex/agents/terra_worker.toml` として再現できるようにする。以後、軽量な調査・限定実装は `gpt-5.6-terra` の custom subagent `terra_worker` を使う。

同時に、`codex-exec` skill は Codex では発見・永続化されない状態を検証する。ただし Claude Code / Pi Agent 向けの `.claude/skills/codex-exec` とその symlink は維持する。

## 調査結果と方針

- Codex の個人用 custom agent は `~/.codex/agents/*.toml` に配置する。agent file は `name`、`description`、`developer_instructions` を必須とし、`model`、`model_reasoning_effort`、`sandbox_mode` は任意である。
- dotfiles は `setup.sh` で repo の source を個別 symlink として `~/.claude`、`~/.pi`、`~/.codex` へ配布している。`.codex/agents/` を repo 内の source location とし、同じ安全な同期方式を追加する。
- 現行 `setup.sh` は `codex-exec`、`codex-review`、`codex-review-file` を `CODEX_EXCLUDED_SKILLS` に指定し、Codex 側の管理 symlink を削除・作成抑止する。`codex-exec` は Claude / Pi Agent 向けの有効 skill のまま残すため、この分離を変更しない。

## 実装

1. `.codex/agents/terra_worker.toml` に、検証済みの `gpt-5.6-terra` worker 定義を追加する。
2. `setup.sh` に Codex agent 同期を追加する。
   - repo 管理下で削除済みになった agent symlink だけを掃除する。
   - source と同一内容の既存 regular file または symlink は、canonical な source symlink へ安全に置換し、壊れた symlink は修復する。
   - 異なる regular file は上書きせず保持する。
3. 本機の `~/.codex` へ内容一致を確認したうえで安全に反映し、agent file が source への symlink になっていることを確認する。PR merge 後の通常の `setup.sh` 実行では canonical な source symlink へ同期する。

## 検証

- `sh -n setup.sh`
- 隔離した一時 `HOME` で `setup.sh` を実行し、agent symlink 作成、同内容 regular file の置換、異内容 regular file の非破壊保持を確認する。
- 実際の `~/.codex` で `terra_worker.toml` の symlink と内容一致を確認する。
- 新規 `codex app-server --strict-config --stdio` プロセスで agent TOML を読み込み、malformed-agent log がないことを確認する。壊した symlink 定義を使う control では同じ scanner がエラーを検出することも確認する。
- `~/.codex/skills/codex-exec` が存在せず、Claude / Pi Agent 側の `codex-exec` symlink は残ることを確認する。
- `codex review --base origin/master` を実行し、指摘があれば修正して再確認する。

## 範囲外

- Obsidian vault と `is01` repo は変更しない。
- current session の skill/agent catalog は hot reload されないため、反映確認は新規 Codex セッションで行う。
