---
name: pr-diff-comment
description: 参考にした既存実装と今回実装の差分を比較し、GitHub Pull Request に通常 comment として投稿する。Codex/Claude/Pi agent から `gh` CLI ベースで使う時に使用
argument-hint: --repo <owner/repo> --pr <number> --reference-path <path> --implementation-path <path> [--dry-run]
---

# PR diff comment skill

呼び出し側が渡した既存実装と今回実装の差分を作り、GitHub Pull Request の通常 comment に投稿する skill です。

## 使いどころ

- 参考にした既存実装との差分を PR の conversation に残したいとき
- review comment ではなく通常 comment で十分なとき
- 比較対象を自動探索せず、呼び出し側で明示的に渡せるとき

## 前提

- `gh` CLI が使えること
- 対象 PR へ comment できる権限で `gh auth login` 済みであること
- 比較対象のファイルは呼び出し側が明示的に渡すこと

## 実行方法

```bash
python3 ~/.claude/skills/pr-diff-comment/scripts/post_pr_diff_comment.py \
  --repo owner/repo \
  --pr 123 \
  --reference-path path/to/reference.sql \
  --implementation-path path/to/implementation.sql
```

Codex からは symlink 後に以下でも実行できます。

```bash
python3 ~/.codex/skills/pr-diff-comment/scripts/post_pr_diff_comment.py \
  --repo owner/repo \
  --pr 123 \
  --reference-path path/to/reference.sql \
  --implementation-path path/to/implementation.sql
```

Pi agent からは以下を使います。

```bash
python3 ~/.pi/agent/skills/pr-diff-comment/scripts/post_pr_diff_comment.py \
  --repo owner/repo \
  --pr 123 \
  --reference-path path/to/reference.sql \
  --implementation-path path/to/implementation.sql
```

## よく使うオプション

- `--reference-label`: comment 上で表示する参考元ラベルを上書きする
- `--implementation-label`: comment 上で表示する実装側ラベルを上書きする
- `--max-diff-lines`: comment に含める diff 行数の上限
- `--title`: comment タイトルを上書きする
- `--dry-run`: 投稿せず本文だけ標準出力に出す

## 例

```bash
python3 ~/.claude/skills/pr-diff-comment/scripts/post_pr_diff_comment.py \
  --repo eure/metis-dbt \
  --pr 2383 \
  --reference-path models/marts/legacy/foo.sql \
  --implementation-path models/marts/bar.sql \
  --reference-label "legacy/foo.sql" \
  --implementation-label "bar.sql" \
  --dry-run
```

## 振る舞い

- unified diff を生成する
- 追加行数、削除行数、ハンク数を要約する
- 長い diff は `--max-diff-lines` を超えた分を省略する
- 差分がない場合もその旨を comment 本文に含める

## 注意

- この skill は review comment ではなく通常 comment を投稿する
- ディレクトリ比較や PR 内の差分位置解決は扱わない
- 初版ではファイルパス比較を前提とする
