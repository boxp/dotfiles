---
name: claude-delegate
description: 別の tmux ペイン（既定）または detached セッション（fallback）で Claude Code にタスクを委譲。「別の claude に任せたい」「tmux で claude を起動して委譲」時に使用
argument-hint: <session-name> <working-directory> <prompt-or-file>
---

# Claude Code タスク委譲

tmux 内では右側の背景ペインに Claude Code を起動して委譲する。tmux 外では従来どおり detached な named session にフォールバックする。

## 引数

- `$ARGUMENTS`: `<session-name> <working-directory> <prompt-or-file>` 形式
  - `session-name`: 委譲先 Claude の識別名。直接テキスト入力時の一時プロンプトファイル名（`/tmp/<session-name>-prompt.txt`）にも使う。fallback ルートでは tmux セッション名にもなる
  - `working-directory`: Claude Code の作業ディレクトリ
  - `prompt-or-file`: 委譲するタスクの説明（直接テキスト or ファイルパス）
  - 例: `my-task /home/user/project /tmp/task-prompt.txt`

## 実行環境の分岐

委譲先の tmux ターゲットは、呼び出し元の環境で決める。

- **pane ルート**（`$TMUX` と `$TMUX_PANE` が両方ある）: 現在のセッションに右側 50% の背景ペインを作り、その `pane_id` を以降の操作対象にする
- **fallback ルート**（上記のいずれかが無い）: detached な named session を作り、セッション名を操作対象にする。tmux 環境変数が無いだけで失敗させない

以降の手順では、次の分岐で `TARGET` と終了方法を決める。

```bash
if [ -n "${TMUX:-}" ] && [ -n "${TMUX_PANE:-}" ]; then
  # pane ルート
  ...
else
  # fallback ルート
  ...
fi
```

## 手順

### 1. プロンプトファイルの準備

- 引数がファイルパスの場合はそのまま使用
- 直接テキストの場合は `/tmp/<session-name>-prompt.txt` に書き出す
- プロンプトには以下を含めること:
  - タスクの背景と設計計画
  - 現状（何が既に完了しているか）
  - やるべきこと（具体的なステップ）
  - 注意事項

### 2. 委譲先 tmux ターゲットの作成

#### pane ルート（tmux 内）

右側 50% の背景ペインを作り、元のペインはフォーカスを維持する。出力された `pane_id` を保存する。

```bash
PANE_ID="$(tmux split-window -h -d -p 50 -c <working-directory> -P -F '#{pane_id}')"
TARGET="$PANE_ID"
```

以降の `send-keys`、`capture-pane`、終了処理はすべて `TARGET`（= `pane_id`）を向ける。

#### fallback ルート（tmux 外）

同名セッションの衝突を避け、detached session を作る。

```bash
tmux has-session -t <session-name> 2>/dev/null && exit 1
tmux new-session -d -s <session-name> -c <working-directory>
TARGET="<session-name>"
```

以降の `send-keys`、`capture-pane`、終了処理はすべて `TARGET`（= セッション名）を向ける。

### 3. Claude Code 起動

```bash
tmux send-keys -t "$TARGET" "cat <prompt-file> | claude" Enter
```

**重要**: `claude --print "$(cat file)"` は使わないこと。シェル展開でプロンプト内容がコマンドとして解釈される。必ず `cat file | claude` のパイプ形式を使う。

### 4. trust 確認の自動承認

Claude Code 起動後、trust 確認プロンプトが表示されるので承認する:

```bash
sleep 5
tmux send-keys -t "$TARGET" Enter
```

### 5. 進捗確認

```bash
tmux capture-pane -t "$TARGET" -p | tail -30
```

## 進捗モニタリング

定期的に委譲先の出力を確認して進捗を把握する:

```bash
# 最新の出力を確認
tmux capture-pane -t "$TARGET" -p | tail -30

# ツール使用許可が必要な場合は承認
tmux send-keys -t "$TARGET" "y" Enter
```

## 完了確認

委譲先の Claude が完了したかを確認:

```bash
tmux capture-pane -t "$TARGET" -p | tail -5
# プロンプト（❯）が表示されていれば完了
```

## 委譲先の終了

```bash
tmux send-keys -t "$TARGET" "/exit" Enter
sleep 2
```

pane ルートではペインを閉じる。fallback ルートではセッションを閉じる。

```bash
# pane ルート
tmux kill-pane -t "$PANE_ID"

# fallback ルート
tmux kill-session -t <session-name>
```

## 注意事項

- 委譲先 Claude はインタラクティブモードで起動するため、ツール使用許可を求められる場合がある
- 長時間タスクの場合は定期的に進捗確認を行う
- fallback ルートでは同じ `session-name` で二重起動しないよう `tmux has-session -t <name>` で事前確認する
- pane ルートでは元のペインにフォーカスが残るため、委譲しながら元の作業を続けやすい
