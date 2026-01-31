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
- 最終出力（Step 3-2の背景色統一後の出力）のみ、ユーザー指定のパスまたはカレントディレクトリに出力する

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
  - **具体的な目標解像度をプロンプトに含めること**（例: 「for 240x160 screen」）
  - 例（GBA BG向け）: `GBA-style pixel art character bust-up for 240x160 screen. True pixel art, crisp 1px edges, no anti-aliasing, no gradients, 64-color palette, optional subtle dithering.`
  - 例（汎用）: `16-bit pixel art style, limited color palette, no anti-aliasing, clean pixel edges`
  - 例（日本語）: 「GBA RPG風ピクセルアート、限定パレット、アンチエイリアスなし、ドット絵」
- 設定ファイルが指定されている場合は、Step 1と同様にその全文をプロンプトに含める
- **出力先は `/tmp` 配下にすること**（例: `/tmp/pixelart_step2.png`）
- 出力ファイルパスを控えておく（Step 3で使用）
- 解像度は1Kで生成すること

### Step 3: true pixel art変換

以下のコマンドを順に実行して、AI生成画像をtrue pixel artに変換する。

#### 3-1. proper-pixel-artでダウンサンプル＋量子化

```bash
uvx --from proper-pixel-art ppa <step2-output> -o <ppa-output> -c <colors> -w <pixel-width> -u 1
```

- `-c`: 量子化色数（デフォルト256、GBA BG向けなら256、GBAスプライト向けなら16など用途に応じて調整）
- `-w`: **入力画像の1ドット幅を手動指定する（必須）**。AI生成のドット絵風画像はクリーンなピクセルグリッドを持たないため、自動検出では正しいドット幅を判定できない。`入力画像の幅 / 目標解像度の幅` で計算する（例: 1K画像(1264px幅)でGBA BG 240px幅を狙う場合、`1264 / 240 ≈ 5` → `-w 5`）
- `-u 1`: **初期アップスケールを無効化する（必須）**。デフォルトでは入力画像が2倍にアップスケールされてから `-w` が適用されるため、`-u 1` を指定しないと出力サイズが想定の2倍になる
- **出力先は `/tmp` 配下にすること**（例: `/tmp/pixelart_step3_ppa.png`）

#### 3-2. グリーン背景の単一色統一（ImageMagick）

AI生成画像はグリーン背景を指定してもピクセルごとに微妙な色ブレが生じる。ppa変換後もこのブレが残るため、最後にグリーン系のピクセルを完全な単一色 `#00FF00` に統一する。

```bash
convert <ppa-output> -fuzz 35% -fill '#00FF00' -opaque '#00FF00' <final-output>
```

- `-fuzz 35%` でグリーンに近い中間色も含めて `#00FF00` に統一する。前景のグリーン系の色まで置換されてしまう場合は値を下げて調整する
- 最終出力はユーザー指定のパスまたはカレントディレクトリに出力する

#### 3-3. 結果確認

出力画像をReadツールで目視確認し、ユーザーに結果を伝える。

## 全体の使用例

### GBA RPG風バストアップの場合

1. generate-imageスキルで高品質イラストを `/tmp/pixelart_step1.png` に生成（アスペクト比 3:2）
2. generate-imageスキルでStep 1の出力を参照し「GBA RPG風ピクセルアート、限定パレット、アンチエイリアスなし」で `/tmp/pixelart_step2.png` に再生成
3. proper-pixel-artでダウンサンプル＋量子化（1264/240≈5 → `-w 5`、`-u 1`で初期アップスケール無効化）:
   ```bash
   uvx --from proper-pixel-art ppa /tmp/pixelart_step2.png -o /tmp/pixelart_step3_ppa.png -c 256 -w 5 -u 1
   ```
4. ImageMagickでグリーン背景を単一色に統一:
   ```bash
   convert /tmp/pixelart_step3_ppa.png -fuzz 35% -fill '#00FF00' -opaque '#00FF00' final.png
   ```
5. Readツールで `final.png` を目視確認

## 依存ツール

- `convert` (ImageMagick) — 背景色の単一色統一
- `uvx` (uv) — proper-pixel-artの実行

## エラー時の対応

- Step 1/2で画像が生成されない → プロンプトを変更して再試行
- Step 3-2で前景のグリーン系の色まで置換される → `-fuzz` 値を下げて調整
- Step 3-2で背景色の統一が不要 → ステップをスキップ
- proper-pixel-artが見つからない → `uvx --from proper-pixel-art ppa --help` で確認
