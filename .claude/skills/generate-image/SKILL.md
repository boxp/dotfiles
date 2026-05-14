---
name: generate-image
description: Gemini 3.1 Flash Image Previewで画像を生成・編集。「画像を生成」「画像を作って」「イラストを描いて」時に使用。Nano Banana Proを使う場合は -m gemini-3-pro-image-preview を指定
argument-hint: "[options] [-m model] <prompt>"
---

# Gemini画像生成スキル

Gemini 3.1 Flash Image Preview (`gemini-3.1-flash-image-preview`) を使って画像を生成・編集します。`-m` オプションでモデルを変更可能です。

## 使用方法

```bash
bb /home/boxp/.claude/skills/generate-image/generate-image.bb [options] "プロンプト"
```

## オプション

$ARGUMENTS

- `-a, --aspect-ratio RATIO` : アスペクト比 (default: 1:1)
- `-s, --size SIZE` : 画像サイズ 1K/2K/4K（gemini-3-pro-image-preview等で有効。未指定時は省略）
- `-m, --model MODEL` : モデル名 (default: gemini-3.1-flash-image-preview)
- `-o, --output PATH` : 出力ファイルパス (default: ./gemini-<timestamp>.<ext>)
- `-i, --image PATH` : 入力画像パス（複数指定可、画像編集やスタイル参照に使用）
- `-h, --help` : ヘルプ表示

## 使用例

### テキストから画像生成
```bash
bb /home/boxp/.claude/skills/generate-image/generate-image.bb "夕焼けの海辺の風景"
```

### アスペクト比・サイズ指定
```bash
bb /home/boxp/.claude/skills/generate-image/generate-image.bb -a 16:9 -s 4K -o banner.png "ヘッダー画像"
```

### 入力画像を参照して生成
```bash
bb /home/boxp/.claude/skills/generate-image/generate-image.bb -i ref.png "この画像をアニメ風にして"
```

### 複数の入力画像を融合
```bash
bb /home/boxp/.claude/skills/generate-image/generate-image.bb -i ref1.png -i ref2.png "これらの画像を融合して"
```

### モデルを指定して生成（例: Nano Banana Pro）
```bash
bb /home/boxp/.claude/skills/generate-image/generate-image.bb -m gemini-3-pro-image-preview -s 2K "夕焼けの海辺の風景"
```

### モデルを指定して生成（例: 低コストな旧Flash）
```bash
bb /home/boxp/.claude/skills/generate-image/generate-image.bb -m gemini-2.5-flash-image "夕焼けの海辺の風景"
```

## 必要な環境変数

- `GEMINI_API_KEY` : Gemini APIキー（必須）

## エラー時の対応

- `GEMINI_API_KEY environment variable is not set` → 環境変数 `GEMINI_API_KEY` を設定してください
- `API returned status 4xx/5xx` → APIキーやリクエスト内容を確認してください
- `No image data in API response` → プロンプトを変更して再試行してください

## 出力

生成された画像のファイルパスが標準出力に表示されます。ユーザーにはそのパスを伝えてください。
