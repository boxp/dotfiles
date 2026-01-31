---
name: generate-pixelart
description: ドット絵・ピクセルアートを生成。「ドット絵を生成」「ピクセルアートを作って」「GBA用の画像を作って」時に使用
argument-hint: "<プロンプトまたは説明>"
---

# ドット絵・ピクセルアート生成スキル

AI画像生成 → ドット絵風再生成 → true pixel art変換の3ステップでドット絵を生成します。

## 引数
- `$ARGUMENTS`: 生成したいドット絵の説明（日本語可）

## 中間ファイルの出力先

- **Step 1〜Step 3-1の中間ファイルはすべて `/tmp` 配下に出力すること**
- 最終出力（Step 3-2のproper-pixel-art出力）のみ、ユーザー指定のパスまたはカレントディレクトリに出力する

## 3ステップの手順

### Step 1: イラスト生成

generate-imageスキルを使い、まず高品質なイラストを生成する。

- ユーザーの指示に基づいたプロンプトでイラストを生成
- **【重要】設定ファイル（キャラ設定等）が指定されている場合は、そのファイルをReadツールで読み込み、プロフィールや設定の全文をそのままプロンプトに含めること。要約や省略は禁止。Geminiにキャラクターの特徴を正確に伝えるために必須。**
- 参照画像があれば指定
- アスペクト比はユーザー指定または用途に応じて選択
- キャラクターやオブジェクトの画像を生成する場合、背景色をグリーン(#00FF00)にすること
- **この段階ではドット絵ではなく高品質なイラストとして生成すること**
- **出力先は `/tmp` 配下にすること**（例: `/tmp/pixelart_step1.png`）
- 出力ファイルパスを控えておく（Step 2で使用）
- 解像度は1Kで生成すること

### Step 2: ドット絵風画像の再生成

generate-imageスキルを使い、Step 1の出力を参照画像として、ドット絵スタイルで再度生成する。

- Step 1の出力画像を参照画像として指定
- プロンプトでピクセルアートスタイルを明確に指定する
  - 例: 「GBA RPG風ピクセルアート、限定パレット、アンチエイリアスなし、ドット絵」
  - 例: 「16-bit pixel art style, limited color palette, no anti-aliasing, clean pixel edges」
- 設定ファイルが指定されている場合は、Step 1と同様にその全文をプロンプトに含める
- **出力先は `/tmp` 配下にすること**（例: `/tmp/pixelart_step2.png`）
- 出力ファイルパスを控えておく（Step 3で使用）
- 解像度は1Kで生成すること

### Step 3: true pixel art変換

以下のコマンドを順に実行して、AI生成画像をtrue pixel artに変換する。

#### 3-1. 背景をグリーンに置換（ImageMagick）

画像の4隅からfloodfillで背景をグリーン(#00FF00)に置換する。
`%[fx:w-1]` 記法はImageMagick 6では動作しないため、先に `identify` で画像サイズを取得し、座標を計算してから実行する。

**【重要】角が前景の場合の安全策:**
floodfillは「角が背景色である」前提で動作する。被写体が画像端まで伸びている構図（全画面キャラ、クロップ画像など）では、角の前景がグリーンに置換されて出力が壊れる。
実行前に以下の手順で安全確認を行うこと:

1. Readツールで画像を目視確認し、4隅が背景色であることを確認する
2. 角に前景（キャラクター等）が存在する場合は、以下のいずれかで対処する:
   - **Step 2のプロンプトで「背景は単色、キャラクターは画像中央に収まるように」と指示して再生成する**（推奨）
   - floodfillを実行する角を、背景色である角のみに限定する（前景がある角はスキップ）
   - このステップ自体をスキップし、proper-pixel-artの `-t` オプションなしで実行する

```bash
# 画像サイズを取得
W=$(identify -format '%w' <step2-output>)
H=$(identify -format '%h' <step2-output>)
# 4隅からfloodfill（座標は0始まりなので w-1, h-1）
# ※ 前景が角にある場合は該当する -draw 行を除外すること
convert <step2-output> -fuzz 8% -fill '#00FF00' \
  -draw "color 0,0 floodfill" \
  -draw "color $((W-1)),0 floodfill" \
  -draw "color 0,$((H-1)) floodfill" \
  -draw "color $((W-1)),$((H-1)) floodfill" \
  <green-bg-output>
```

- **出力先は `/tmp` 配下にすること**（例: `/tmp/pixelart_step2_green.png`）
- `-fuzz` の値は背景と前景の色差に応じて調整（デフォルト8%、背景が複雑なら下げる）
- 背景がキャラクターと十分異なる場合や、すでにグリーン背景の場合はこのステップをスキップ可能

#### 3-2. proper-pixel-artでダウンサンプル＋量子化

```bash
uvx --from proper-pixel-art ppa <green-bg-output> -o <final-output> -c <colors> -t
```

- `-c`: 量子化色数（デフォルト256、GBA向けなら16や64など用途に応じて調整）
- `-t`: 4隅からfloodfillで背景を透明化（背景色は自動検出）

#### 3-3. 結果確認

出力画像をReadツールで目視確認し、ユーザーに結果を伝える。

## 全体の使用例

### GBA RPG風バストアップの場合

1. generate-imageスキルで高品質イラストを `/tmp/pixelart_step1.png` に生成（アスペクト比 3:2）
2. generate-imageスキルでStep 1の出力を参照し「GBA RPG風ピクセルアート、限定パレット、アンチエイリアスなし」で `/tmp/pixelart_step2.png` に再生成
3. ImageMagickで背景をマゼンタに置換:
   ```bash
   W=$(identify -format '%w' /tmp/pixelart_step2.png)
   H=$(identify -format '%h' /tmp/pixelart_step2.png)
   convert /tmp/pixelart_step2.png -fuzz 8% -fill '#00FF00' \
     -draw "color 0,0 floodfill" \
     -draw "color $((W-1)),0 floodfill" \
     -draw "color 0,$((H-1)) floodfill" \
     -draw "color $((W-1)),$((H-1)) floodfill" \
     /tmp/pixelart_step2_green.png
   ```
4. proper-pixel-artで最終出力（ユーザー指定パスまたはカレントディレクトリ）に変換:
   ```bash
   uvx --from proper-pixel-art ppa /tmp/pixelart_step2_green.png -o final.png -c 64 -t
   ```
5. Readツールで `final.png` を目視確認

## 依存ツール

- `convert` (ImageMagick) — 背景色置換
- `uvx` (uv) — proper-pixel-artの実行

## エラー時の対応

- Step 1/2で画像が生成されない → プロンプトを変更して再試行
- Step 3-1でfloodfillが不適切 → `-fuzz` 値を調整（大きくすると広範囲に置換）
- Step 3-1で背景置換が不要 → ステップをスキップ
- proper-pixel-artが見つからない → `uvx --from proper-pixel-art ppa --help` で確認
