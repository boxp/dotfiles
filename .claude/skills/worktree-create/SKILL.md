---
name: worktree-create
description: gwqを使って新しいworktreeを作成。「新しいブランチで作業したい」「feature branchを切りたい」時に使用
argument-hint: <branch-name>
---

# Worktree作成

gwqを使って新しいworktreeを作成します。

## 引数
- `$ARGUMENTS`: ブランチ名（例: `feature/new-feature`）

## 手順

1. 現在のリポジトリでworktreeを作成:
   ```bash
   gwq add -b $ARGUMENTS
   ```

2. 作成後、worktreeのパスを取得して移動可能:
   ```bash
   cd $(gwq get $ARGUMENTS)
   ```

3. 作成されたworktreeの確認:
   ```bash
   gwq list -v
   ```

## オプション
- 既存ブランチから作成: `gwq add <branch>`
- インタラクティブ選択: `gwq add -i`
- 作成後そのまま移動: `gwq add -s <branch>`
