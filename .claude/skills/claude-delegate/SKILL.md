---
name: claude-delegate
description: 別のtmuxセッションでClaude Codeにタスクを委譲。「別のclaudeに任せたい」「tmuxでclaudeを起動して委譲」時に使用
argument-hint: <session-name> <working-directory> <prompt-or-file>
---

# Claude Code タスク委譲

別のtmuxセッションでClaude Codeを起動し、タスクを委譲します。

## 引数
- `$ARGUMENTS`: `<session-name> <working-directory> <prompt-or-file>` 形式
  - session-name: tmuxセッション名
  - working-directory: Claude Codeの作業ディレクトリ
  - prompt-or-file: 委譲するタスクの説明（直接テキスト or ファイルパス）
  - 例: `my-task /home/user/project /tmp/task-prompt.txt`

## 手順

### 1. プロンプトファイルの準備
- 引数がファイルパスの場合はそのまま使用
- 直接テキストの場合は `/tmp/<session-name>-prompt.txt` に書き出す
- プロンプトには以下を含めること:
  - タスクの背景と設計計画
  - 現状（何が既に完了しているか）
  - やるべきこと（具体的なステップ）
  - 注意事項

### 2. tmuxセッション作成
```bash
tmux new-session -d -s <session-name> -c <working-directory>
```

### 3. Claude Code起動
```bash
tmux send-keys -t <session-name> "cat <prompt-file> | claude" Enter
```

**重要**: `claude --print "$(cat file)"` は使わないこと。シェル展開でプロンプト内容がコマンドとして解釈される。必ず `cat file | claude` のパイプ形式を使う。

### 4. trust確認の自動承認
Claude Code起動後、trust確認プロンプトが表示されるので承認する:
```bash
sleep 5
tmux send-keys -t <session-name> Enter
```

### 5. 進捗確認
```bash
tmux capture-pane -t <session-name> -p | tail -30
```

## 進捗モニタリング

定期的にセッションの出力を確認して進捗を把握する:
```bash
# 最新の出力を確認
tmux capture-pane -t <session-name> -p | tail -30

# ツール使用許可が必要な場合は承認
tmux send-keys -t <session-name> "y" Enter
```

## 完了確認

委譲先のClaudeが完了したかを確認:
```bash
tmux capture-pane -t <session-name> -p | tail -5
# プロンプト（❯）が表示されていれば完了
```

## セッション終了
```bash
tmux send-keys -t <session-name> "/exit" Enter
sleep 2
tmux kill-session -t <session-name>
```

## 注意事項
- 委譲先Claudeはインタラクティブモードで起動するため、ツール使用許可を求められる場合がある
- 長時間タスクの場合は定期的に進捗確認を行う
- 同じセッション名で二重起動しないよう `tmux has-session -t <name>` で事前確認する
