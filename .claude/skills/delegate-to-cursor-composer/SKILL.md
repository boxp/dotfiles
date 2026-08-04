---
name: delegate-to-cursor-composer
description: Cursor Agent CLI の Composer 2 系モデルへ実装作業を委譲し、push と Draft PR 作成までを detached な named tmux セッションで実行させる skill。Claude Code / Codex / Pi Agent から「Cursor Composer に任せたい」「別セッションで Cursor に実装させたい」「作業 branch で実装して Draft PR だけ作らせたい」ときに使う。委任元は対象リポジトリのPRテンプレートに準拠した本文を作成し、Cursor には指定済み本文を使わせる。merge、close、branch delete、force-push、amend、Jira やチケットへのコメントはさせない。
---

# Cursor Composer への委譲

Cursor Agent CLI を detached な named tmux セッションで非対話・一回実行し、対象リポジトリまたは worktree で実装、検証、commit、push、Draft PR 作成だけを実行させる。呼び出し元が tmux 内でも pane を分割せず、常に新しい detached session を作る。委任元は進捗をポーリングせず、終了通知と状態ファイルで結果を受け取る。実行中は stream-json を人間可読に整形した進行ログが pane と `output.log` にリアルタイム表示される。

PR 本文は、委任元が対象リポジトリのPRテンプレートを検出して準拠したファイルを用意し、Cursor にそのまま使わせる。Cursor に PR 本文の創作や運用判断をさせない。

既定モデルは `composer-2.5-fast` とし、より高品質側へ寄せたいときだけ `composer-2.5` へ切り替える。

## 入力の基本形

- `$ARGUMENTS`: `<session-name> <target-repo-or-worktree> <task-or-prompt-file>`
- `session-name`: 委譲先 Cursor の識別名。`/tmp/cursor-composer-delegate/<session-name>/` のディレクトリ名と tmux セッション名の両方に使う
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

### 2. PR テンプレートを検出し、本文ファイルを委任元が用意する

PR 本文を作る前に、対象リポジトリのPRテンプレートを必ず確認する。次の候補を確認し、該当するテンプレートを読む。

```bash
find .github -maxdepth 2 -type f \( -iname 'PULL_REQUEST_TEMPLATE.md' -o -iname 'pull_request_template.md' \) -print
```

- テンプレートが1件なら、それを本文の基底にする。
- 複数テンプレートがあり、タスクから対象を一意に決められない場合は、PR作成前に委任元ユーザーへ選択を確認する。
- テンプレートがない場合だけ、委任元がタスクに応じた本文を作る。

委任前に必ず次のディレクトリを作る。

```bash
mkdir -p /tmp/cursor-composer-delegate/<session-name>
```

この配下に次の 2 ファイルを置く。

- `prompt.md`: Cursor に渡す最終 prompt
- `pr-body.md`: Draft PR の本文。委任元責任で作る

`task-or-prompt-file` がファイルなら内容を参照し、そこに PR 本文が含まれていなければ別途 `pr-body.md` を作る。直接テキスト入力なら委任元の意図に基づいて `prompt.md` と `pr-body.md` を作る。

テンプレートがある場合の `pr-body.md` は次を満たす。

- テンプレートの全セクションと必須チェック項目を残す。該当しない項目も削除せず、`N/A` と理由を記載する。
- `<...>`、`[ticket_url]`、`[changes]` などの未置換プレースホルダーを残さない。
- タスクから確定できる事実だけを記載し、Jira URL・モデル名・検証結果を推測で作らない。
- 既存テンプレートに追加の必須情報がある場合だけ、テンプレートの見出しを維持したまま補足する。

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
- 検出したPRテンプレートのパス、またはテンプレートがないこと
- PR本文がテンプレートの全セクションを保持し、未置換プレースホルダーを含まないことを確認する指示
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
- Template: <detected template path, or none>
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

### 5. detached session を作り、共通ランナー経由で Cursor Agent を起動する

同名セッションの衝突を避け、常に detached session を作る。呼び出し元が tmux 内でも pane を分割しない。

```bash
tmux has-session -t <session-name> 2>/dev/null && exit 1
tmux new-session -d -s <session-name> -c <target-repo-or-worktree>
RUNNER="<dotfiles>/.claude/skills/claude-delegate/scripts/run-delegate.sh"
COMMAND="$(printf '%q ' "$RUNNER" --session-id <session-name> --working-directory <target-repo-or-worktree> -- cursor-agent --print --output-format stream-json --stream-partial-output --force --trust --model composer-2.5-fast --workspace <target-repo-or-worktree> @<prompt-file>); tmux wait-for -S ai-delegate-<session-name>; tmux kill-session -t <session-name>"
tmux send-keys -t <session-name> "$COMMAND" Enter
```

`COMMAND` は共通ランナーを先に実行し、ランナーが `status`、`exit_code`、`output.log` など最終状態を書き終えてから `tmux wait-for -S` で完了シグナルを送り、`tmux kill-session` で委譲先セッションだけを閉じる。`;` でつなぐので成功・失敗どちらでもシグナル送信とセッション終了が行われる。状態ファイルとログは `/tmp/ai-delegate/<session-name>/` に残る。

### 5a. 完了をブロッキング待機で検知する

起動直後に、チャンネル `ai-delegate-<session-name>` をブロック待機する Bash を **`run_in_background: true`** で1回だけ実行する。シグナルされるまで出力はなく、ハーネスがバックグラウンドコマンドの完了を自動通知する。

```bash
tmux wait-for ai-delegate-<session-name>
```

`run-delegate.sh` 完了時、`COMMAND` 内の `tmux wait-for -S ai-delegate-<session-name>` が上記待機を解除する。通知を受け取った時点で初めて状態ファイルを1回だけ確認する。

ランナーは `/tmp/ai-delegate/<session-name>/` に `started_at`、`finished_at`、`exit_code`、`status`（`success` / `failed`）、`output.log` を保存し、終了時には macOS 通知を試行する。通知権限がない場合も状態ファイルは残る。

### 6. 必要時だけ終了状態を確認する

必要に応じて出力を確認する。完了後はセッションが閉じているため、状態ファイルとログを主に使う。

```bash
cat /tmp/ai-delegate/<session-name>/status
cat /tmp/ai-delegate/<session-name>/exit_code
tail -80 /tmp/ai-delegate/<session-name>/output.log
# 実行中だけ。完了後はセッションが閉じている
tmux capture-pane -t <session-name> -p | tail -80
```

進捗を読むための定期的な `capture-pane` や状態ファイルの polling はしない。完了確認は `tmux wait-for` のバックグラウンド待機が通知するまで待つ。失敗時は状態・最終ログを確認し、必要なら prompt を修正して新しい session-name で再実行する。

## 委任時の必須制約

- Cursor の責務は `実装 -> 検証 -> commit -> push -> Draft PR作成` に限定する
- Draft ではない PR を作らせない
- PR description の責任は委任元にある
- 委任元はPR本文作成前に対象リポジトリのPRテンプレートを検出し、テンプレートがあれば全セクションを保持して本文へ反映する
- `gh pr merge`、merge button 操作、branch delete、issue close、Jira コメント、チケットコメント、force-push、amend を禁止する
- 既存 dirty work を見つけたら、その扱いを prompt に明記する
- 失敗時は勝手に運用判断させず、失敗コマンドと状況を残して止めさせる

## 完了確認

委任元は少なくとも次を確認する。

```bash
cat /tmp/ai-delegate/<session-name>/status
tail -80 /tmp/ai-delegate/<session-name>/output.log
git -C <target-repo-or-worktree> status --short --branch
```

完了条件は以下。

- 実装と検証が終わっている
- 変更は対象ブランチへ commit 済み
- `origin/<working-branch>` へ push 済み
- Draft PR が 1 件作成されている
- 禁止事項に触れていない

## 委譲先セッションの終了

委譲先 tmux セッションは、共通ランナーが最終状態を書き終えたあと `COMMAND` 内の `tmux kill-session -t <session-name>` で自動的に閉じる。状態ファイルとログは `/tmp/ai-delegate/<session-name>/` に残る。

ランナー完了前にセッションだけ落ちた場合は、状態ファイルと `output.log` を確認する。不要な残留セッションがあれば手動で閉じる。

```bash
tmux kill-session -t <session-name>
```

同じ `session-name` を二重起動しない。再実行するときは新しい session-name を使う。

## 例外対応

- PR 本文テンプレートが無い場合だけ、委任元がタスクに基づく本文を作る
- 対象 repo に unrelated dirty work がある場合は、そのままでも安全に避けられるときだけ続行する
- `gh` 認証、`cursor-agent` 認証、ネットワーク失敗は Cursor に復旧方針を創作させず、失敗内容を報告させる
