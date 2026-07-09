---
name: delegate-to-cursor-composer
description: Cursor Agent CLI の Composer 2 系モデルへ実装作業を委譲し、push と Draft PR 作成までを別 tmux セッションで実行させる skill。Claude Code / Codex / Pi Agent から「Cursor Composer に任せたい」「別セッションで Cursor に実装させたい」「作業 branch で実装して Draft PR だけ作らせたい」ときに使う。PR description は委任元が作成し、Cursor には指定済み PR 本文ファイルを使わせる。merge、close、branch delete、force-push、amend、Jira やチケットへのコメントはさせない。
---

# Cursor Composer への委譲

Cursor Agent CLI を tmux セッションで起動し、対象リポジトリまたは worktree で実装、検証、commit、push、Draft PR 作成だけを実行させる。

PR 本文は委任元が用意したファイルを Cursor にそのまま使わせる。Cursor に PR 本文の創作や運用判断をさせない。

既定モデルは `composer-2.5-fast` とし、より高品質側へ寄せたいときだけ `composer-2.5` へ切り替える。

## 入力の基本形

- `$ARGUMENTS`: `<session-name> <target-repo-or-worktree> <task-or-prompt-file>`
- `session-name`: tmux と Cursor Agent の識別名
- `target-repo-or-worktree`: 作業対象ディレクトリ
- `task-or-prompt-file`: 委譲タスク本文。直接テキストでもファイルでもよい
- 例:
  - `foo-service-pr ~/ghq/github.com/org/foo-service=feature-bar /tmp/foo-task.md`
  - `lint-fix ~/ghq/github.com/org/foo-service=feature-bar "lint error を直して test を通し、Draft PR を作って"`

情報が足りない場合は次の順で補完する。

1. 対象ディレクトリの `git` 状態から repo、現在 branch、default branch、既存 dirty work を読む
2. タスク本文から成功条件、検証コマンド、PR title、PR body source を読む
3. 補完できない要素だけ委任元ユーザーへ確認する

## 実行手順

### 1. 対象ディレクトリの前提確認

対象ディレクトリに入り、最低限これを確認する。

```bash
git status --short --branch
git remote -v
git branch --show-current
git remote show origin | sed -n '/HEAD branch/s/.*: //p'
```

既存の dirty work があれば、Cursor にその変更へ触れさせない前提で prompt に明記する。対象が git repo でない、または branch が解決できない場合だけ追加確認する。

### 2. PR 本文ファイルを委任元が用意する

委任前に必ず次のディレクトリを作る。

```bash
mkdir -p /tmp/cursor-composer-delegate/<session-name>
```

この配下に次の 2 ファイルを置く。

- `prompt.md`: Cursor に渡す最終 prompt
- `pr-body.md`: Draft PR の本文。委任元責任で作る

`task-or-prompt-file` がファイルなら内容を参照し、そこに PR 本文が含まれていなければ別途 `pr-body.md` を作る。直接テキスト入力なら委任元の意図に基づいて `prompt.md` と `pr-body.md` を作る。

Cursor には `pr-body.md` を原則そのまま使わせる。事実の穴埋め以外で書き換えさせない。

### 3. Cursor 用 prompt を構築する

`prompt.md` には必ず次を含める。

- task goal
- 対象 repo / worktree path
- base branch
- 作業 branch
- 成功条件
- 実行すべき検証コマンド
- PR title
- PR body file path
- 作業前後に `git status --short --branch` を確認する指示
- `gh pr create --draft --title "<title>" --body-file "<pr-body-file>"` を使う指示
- 禁止事項

最低限の雛形は次を守る。

```text
# Task
- Goal: ...
- Repo: ...
- Worktree: ...
- Base branch: ...
- Working branch: ...

# Success Criteria
- ...

# Validation
[run the validation commands here]

# PR
- Title: ...
- Body file: /tmp/cursor-composer-delegate/<session>/pr-body.md
- Create command:
  `gh pr create --draft --title "..." --body-file "/tmp/cursor-composer-delegate/<session>/pr-body.md"`

# Required Git Hygiene
- Run `git status --short --branch` before edits and again before commit/push.
- Do not touch unrelated dirty files.
- Do not use `git commit --amend`.
- Do not use `git push --force` or `--force-with-lease`.

# Prohibited Actions
- Do not merge a PR.
- Do not close a PR or issue.
- Do not delete any branch.
- Do not post Jira or ticket comments.
- Do not rewrite the PR body except factual placeholder replacement explicitly allowed by the delegator.
```

禁止事項は曖昧にせず、毎回 prompt に明記する。

### 4. Cursor Agent CLI とモデルを確認する

Cursor 起動前に CLI と対象モデルが見えるか確認する。

```bash
command -v cursor-agent
cursor-agent models
```

既定は `composer-2.5-fast` を使う。出力に見当たらない場合だけ `composer-2.5` など利用可能モデルへ切り替える。CLI 自体が無い場合は委任元側でインストール状況を整えてから再実行する。

### 5. tmux セッションで Cursor Agent を起動する

同名セッションの衝突を避ける。

```bash
tmux has-session -t <session-name> 2>/dev/null && exit 1
tmux new-session -d -s <session-name> -c <target-repo-or-worktree>
tmux send-keys -t <session-name> 'cursor-agent --model composer-2.5-fast --workspace "<target-repo-or-worktree>" --force @"<prompt-file>"' Enter
```

`cursor-agent` の単発実行より、tmux の対話セッションを既定にする。長時間実装、失敗時の介入、再読の確認を追いやすいため。

### 6. 進捗を監視する

必要に応じて出力を確認する。

```bash
tmux capture-pane -t <session-name> -p | tail -50
```

途中で Cursor が禁止事項に触れそうなら停止させ、prompt を修正して再実行する。

## 委任時の必須制約

- Cursor の責務は `実装 -> 検証 -> commit -> push -> Draft PR作成` に限定する
- Draft ではない PR を作らせない
- PR description の責任は委任元にある
- `gh pr merge`、merge button 操作、branch delete、issue close、Jira コメント、チケットコメント、force-push、amend を禁止する
- 既存 dirty work を見つけたら、その扱いを prompt に明記する
- 失敗時は勝手に運用判断させず、失敗コマンドと状況を残して止めさせる

## 完了確認

委任元は少なくとも次を確認する。

```bash
tmux capture-pane -t <session-name> -p | tail -80
git -C <target-repo-or-worktree> status --short --branch
```

完了条件は以下。

- 実装と検証が終わっている
- 変更は対象ブランチへ commit 済み
- `origin/<working-branch>` へ push 済み
- Draft PR が 1 件作成されている
- 禁止事項に触れていない

## 例外対応

- PR 本文テンプレートが無いまま委任依頼されたら、先に委任元が本文を作る
- 対象 repo に unrelated dirty work がある場合は、そのままでも安全に避けられるときだけ続行する
- `gh` 認証、`cursor-agent` 認証、ネットワーク失敗は Cursor に復旧方針を創作させず、失敗内容を報告させる
