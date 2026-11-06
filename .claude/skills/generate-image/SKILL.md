---
name: generate-image
description: Codex native image_gen で画像を生成・編集する。画像生成、イラスト、参照画像の編集に使用。
argument-hint: "[options] <prompt>"
---

# Codex native image_gen

ChatGPT subscription でログインした Codex の組込み image_gen を使う。Gemini や別課金 API は使わない。画像生成枠は有限なので必要な枚数を先に決め、無駄な生成や自動再試行をしない。

**Codex 内でこの skill を使う場合は `codex exec` を再帰起動せず、自分の組込み image_gen を直接呼ぶ。** 参照画像はツールの画像入力として実際に添付する。Codex 外（Claude / Pi / shell）では次を使う。

```sh
bb ~/.claude/skills/generate-image/generate-image.bb -i reference.png -o output.png -a 1:1 -s 1K "プロンプト"
```

`-i` は複数指定可。`-a` と `-s` はプロンプトによる希望であり寸法を保証しない。`--dry-run` は Codex を起動せずコマンドと指示を表示する。`-m` と `-S` は非対応。`-h` でヘルプを表示する。入力先は存在し、出力先ディレクトリは作成済みであること。Babashka と Codex CLI が必要。

ChatGPT ログインと `image_generation` feature を確認し、1回だけ生成を試みる。失敗時は非ゼロで終了し他の API にフォールバックしない。成功時は PNG と、プロンプト・入出力ハッシュ・寸法などを含む `<output>.json` を保存する。プロンプトや画像の機密性に応じて保存先を管理する。
