---
name: generate-image
description: Gemini画像生成（Nano Banana）。「画像を生成」「画像を作って」「イラストを描いて」時に使用。NB2は -m gemini-3.1-flash-image-preview、NB Proは -m gemini-3-pro-image-preview を指定
argument-hint: "[options] [-m model] <prompt>"
---

# Gemini画像生成スキル

Gemini 2.5 Flash Image (`gemini-2.5-flash-image`) を使って画像を生成・編集します。`-m` オプションでモデルを変更可能です。

## 利用可能なモデル

| コードネーム | モデルID | 1K画像コスト | 特徴 |
|---|---|---|---|
| **Nano Banana (NB1)** | `gemini-2.5-flash-image` | $0.039/枚 | デフォルト。高速・最安。参照画像スタイル変換は苦手 |
| **Nano Banana 2 (NB2)** | `gemini-3.1-flash-image-preview` | $0.067/枚 (1K) | 高効率＋多解像度(512px/1K/2K/4K)。参照画像ベースの変換も対応 |
| **Nano Banana Pro** | `gemini-3-pro-image-preview` | $0.134/枚 (1K/2K) | 最高品質。Thinking搭載、高精度テキスト描画、プロ用途向け |

## 使用方法

```bash
bb /home/boxp/.claude/skills/generate-image/generate-image.bb [options] "プロンプト"
```

## オプション

$ARGUMENTS

- `-a, --aspect-ratio RATIO` : アスペクト比 (default: 1:1)
- `-s, --size SIZE` : 画像サイズ 512/1K/2K/4K（NB2・NB Pro等で有効。未指定時は省略）
- `-m, --model MODEL` : モデル名 (default: gemini-2.5-flash-image)
- `-o, --output PATH` : 出力ファイルパス (default: ./gemini-<timestamp>.<ext>)
- `-i, --image PATH` : 入力画像パス（複数指定可、画像編集やスタイル参照に使用）
- `-h, --help` : ヘルプ表示

## 使用例

### テキストから画像生成（デフォルト: NB1）
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

### Nano Banana 2 で生成（コスト効率◎、多解像度対応）
```bash
bb /home/boxp/.claude/skills/generate-image/generate-image.bb -m gemini-3.1-flash-image-preview -s 1K "夕焼けの海辺の風景"
```

### Nano Banana Pro で生成（最高品質）
```bash
bb /home/boxp/.claude/skills/generate-image/generate-image.bb -m gemini-3-pro-image-preview -s 2K "夕焼けの海辺の風景"
```

## モデル選択ガイド

- **テキストから単純な画像生成** → NB1（デフォルト、最安）
- **参照画像ベースの編集・スタイル変換** → NB2（NB1より高品質で、NB Proの約半額）
- **高精度テキスト描画・プロ品質が必要** → NB Pro（最高品質だがコスト高）
- **ドット絵パイプライン（generate-pixelart）** → NB2推奨（コスト最適化。品質が不十分な場合はNB Proにフォールバック）

## 必要な環境変数

- `GEMINI_API_KEY` : Gemini APIキー（必須）

## エラー時の対応

- `GEMINI_API_KEY environment variable is not set` → 環境変数 `GEMINI_API_KEY` を設定してください
- `API returned status 4xx/5xx` → APIキーやリクエスト内容を確認してください
- `No image data in API response` → プロンプトを変更して再試行してください

## 出力

生成された画像のファイルパスが標準出力に表示されます。ユーザーにはそのパスを伝えてください。
