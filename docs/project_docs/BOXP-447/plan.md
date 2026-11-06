# BOXP-447: 画像生成を Gemini API から Codex native image_gen へ移行

## 方針
- `generate-image` skill（Claude / Pi / Codex 共通、Novel Board runner・定期小説 cron が呼ぶ）を Codex CLI の組込み image_gen 経路へ置換する。
- ChatGPT subscription login と `image_generation` feature を必須とし、API key login / OpenAI 従量 API / Gemini への fallback は持たない。
- `-i` 参照画像は `codex exec -i` で実添付。1 呼出し 1 生成・retry なし。`<output>.json` に prompt・入出力 sha256・寸法・経路を記録。
- 共有 `GEMINI_API_KEY` の配布（arch / lolice）は非画像用途があるため削除しない。
- 棚卸し・ledger: vault `Projects/image-generation-codex-migration/`。

## 検証
- stub テスト `bash .claude/skills/generate-image/tests/run-tests.sh`（添付、login 拒否、失敗時 retry なし、gemini モデル拒否、旧 endpoint/key 名不在）。
- 実生成 E2E: SFW 参照画像 1 枚で背景変更 1 call 成功（vault ledger 参照）。

## 残件
- 配備（dotfiles master → 各環境の dotfiles sync）後に Novel Board sidecar / 定期 cron 実行環境で login・sandbox・生成を確認。
- Novel Board runner の pending PNG 昇格時の `.json` 扱い、even-g2-lab 手順の旧 `-m gemini-*` 記述更新、Hermes default の実環境調査。
