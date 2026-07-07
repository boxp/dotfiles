# BOXP-56 codex-review 再帰ガード計画

## Context

`codex-review` skill は `codex review` コマンドを起動するための skill である。レビューを実行している Codex 自身がレビュー用プロンプト内の「codex review」や「codexでレビュー」という文言に反応して同じ skill を再起動すると、レビュー処理が再帰して終わらない可能性がある。

## 変更対象

- `.claude/skills/codex-review/SKILL.md`
- `.claude/skills/codex-review-file/SKILL.md`
- `setup.sh`

## 実装方針

- `codex-review` に、`codex review` 実行中またはレビュー担当として起動された Codex はこの skill を再起動しない、というガードを追加する。
- レビュー担当 Codex は、受け取った差分・ファイル・指示をそのまま評価し、必要があれば通常の読み取りコマンドだけで確認する、という扱いを明記する。
- 通常用途である未コミット差分、base 差分、commit 差分のレビュー手順は維持する。
- `codex-review-file` も `codex exec` で別 Codex を起動する近接 skill なので、レビュー担当 Codex からの再呼び出し禁止を同様に明記する。
- `setup.sh` の `CODEX_EXCLUDED_SKILLS` に `codex-review` と `codex-review-file` を追加し、Codex 側の skill symlink から除外する。
- 既存の `~/.codex/skills` symlink も除外対象なら削除されるように cleanup 条件を更新する。

## 検証方法

- `SKILL.md` の差分を確認し、通常の実行例が残っていることを確認する。
- ガード文言として「レビュー担当 Codex はこの skill を再起動しない」ことが明示されているか確認する。
- `setup.sh` を dry-run 相当の一時 HOME で実行し、`codex-review` と `codex-review-file` が `~/.codex/skills` に作成されないことを確認する。
- 既存 symlink がある状態で `setup.sh` を実行し、除外対象 symlink が削除されることを確認する。
- セルフチェックでは `codex review` コマンドを実行せず、`git diff` とテキスト確認で再帰リスクを検証する。
