# BOXP-193: jev-lint 導入評価（送信なし）

[mizchi/jev-lint](https://github.com/mizchi/jev-lint) を dotfiles の PR で非ブロッキング advisory として試せるかを、API を呼ばずに評価するためのファイル群。設計と評価記録の本体は Vault の `Projects/jev-lint-adoption/design.md` にある。

ここにあるものは評価専用で、advisory workflow・API key・CI secret は導入していない。`.github/workflows/jev-lint-eval.yml` はこの評価用ファイルの構文と負例 fixtures を検証するだけで、secret を使わず、送信もしない。

## ファイル

| ファイル | 役割 |
|---|---|
| `tool/package.json`、`tool/package-lock.json` | `jev-lint@0.7.0` と依存の固定（integrity 付き） |
| `jev-lint.pilot.yaml` | 設定案。正確な path 2 件と rule 3 件、cache 無効 |
| `allowlist.txt` | 送信候補にしてよい正確な path |
| `denylist.txt` | 機密 path の glob。allowlist より優先 |
| `content-deny.txt` | 内容検査の正規表現 |
| `dry-run-eval.sh` | gate、隔離 staging、network 遮断下の dry-run、負例 fixtures |

## 実行

Node 24 以上、`jq`、`unshare` が必要。

```sh
cd docs/project_docs/BOXP-193/tool
npm ci --ignore-scripts          # 取得だけ network を使う
cd ..
./dry-run-eval.sh fixtures
./dry-run-eval.sh run --repo "$(git rev-parse --show-toplevel)" \
  --base b4453c282ab3bd10c877fea6ebe3b88b0a050fab \
  --head d1f0fa2ff8cd18ff10d0139adb472a05dbd3d1d2
```

`jev-lint` は常に `--dry-run --cache none` で、network namespace と環境変数を切り離して起動する。

## 2026-09-29 の結果

- fixtures: 全件期待どおり（内容検査、旧版の秘密値、symlink、削除、rename、denylist、巨大ファイル、対象 0 件、11 ファイル変更）。
- dotfiles `b4453c2..d1f0fa2`: 1 request、4,587 token、概算 $0.00019、約 0.2 秒。
- `setup.sh` は変更 36 行に対し、`state: located` のため全文が送信対象になる。
- `AGENTS.md` は 1 行削除のみで、判定対象は 0 件だった。

見積りは実装定数による概算で、実費・応答時間・判定品質は計測していない。ライブ送信は API 側の契約条件（価格、上限、保持、学習利用、リージョン）が確認できるまで行わない。
