---
name: generate-image
description: Gemini Nano Banana Proで画像を生成・編集。「画像を生成」「画像を作って」「イラストを描いて」時に使用
argument-hint: "[options] <prompt>"
---

# Gemini画像生成スキル

Gemini 3 Pro (`gemini-3-pro-image-preview`) を使って画像を生成・編集します。

## 使用方法

```bash
bb /home/boxp/.claude/skills/generate-image/generate-image.bb [options] "プロンプト"
```

## オプション

$ARGUMENTS

- `-a, --aspect-ratio RATIO` : アスペクト比 (default: 1:1)
- `-s, --size SIZE` : 画像サイズ 1K/2K/4K (default: 2K)
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

## 必要な環境変数

- `GEMINI_API_KEY` : Gemini APIキー（必須）

## エラー時の対応

- `GEMINI_API_KEY environment variable is not set` → 環境変数 `GEMINI_API_KEY` を設定してください
- `API returned status 4xx/5xx` → APIキーやリクエスト内容を確認してください
- `No image data in API response` → プロンプトを変更して再試行してください

## 出力

生成された画像のファイルパスが標準出力に表示されます。ユーザーにはそのパスを伝えてください。
