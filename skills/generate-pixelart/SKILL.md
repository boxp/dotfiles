---
name: generate-pixelart
description: ドット絵・ピクセルアートを生成。「ドット絵を生成」「ピクセルアートを作って」「GBA用の画像を作って」時に使用
argument-hint: "<プロンプトまたは説明>"
---

# ドット絵・ピクセルアート生成スキル

AI画像生成 → ドット絵風再生成 → true pixel art変換の3ステップでドット絵を生成します。

**【重要】generate-imageスキルの呼び出し時は、必ず `-m gemini-3-pro-image-preview -s 1K` を指定してNano Banana Proモデルを使用すること。** デフォルトのNano Banana（gemini-2.5-flash-image）は参照画像ベースのスタイル変換（Step 2）が効かないため、ドット絵パイプラインには不向き。

## 引数
- `$ARGUMENTS`: 生成したいドット絵の説明（日本語可）

## 中間ファイルの出力先

- **Step 1〜Step 3の中間ファイルはすべて `/tmp` 配下に出力すること**
- 最終出力（Step 3のproper-pixel-art出力）のみ、ユーザー指定のパスまたはカレントディレクトリに出力する

## 3ステップの手順

### Step 1: イラスト生成

generate-imageスキルを使い、まず高品質なイラストを生成する。

- ユーザーの指示に基づいたプロンプトでイラストを生成
- **【重要】設定ファイル（キャラ設定等）が指定されている場合は、そのファイルをReadツールで読み込み、プロフィールや設定の全文をそのままプロンプトに含めること。要約や省略は禁止。Geminiにキャラクターの特徴を正確に伝えるために必須。**
- 参照画像があれば指定
- アスペクト比はユーザー指定または用途に応じて選択
- キャラクターやオブジェクトの画像を生成する場合、背景色をグリーン(#00FF00)にすること
- **この段階ではドット絵ではなく高品質なイラストとして生成すること**
- **generate-imageスキルに `-m gemini-3-pro-image-preview -s 1K` を必ず指定すること**
- **出力先は `/tmp` 配下にすること**（例: `/tmp/pixelart_step1.png`）
- 出力ファイルパスを控えておく（Step 2で使用）

### Step 2: ドット絵風画像の再生成

generate-imageスキルを使い、Step 1の出力を参照画像として、ドット絵スタイルで再度生成する。

- Step 1の出力画像を参照画像として指定
- プロンプトでピクセルアートスタイルを明確に指定する
  - **具体的な目標解像度をプロンプトに含めること。ただし、長辺が128pxを超える場合はアスペクト比を維持したまま長辺を128pxに縮小した解像度を指定する**（例: 目標240x160の場合 → 128x85としてプロンプトに含める）。AI画像生成では解像度を小さく伝えた方がよりドット絵らしい粗さの画像が生成される
  - 例（GBA BG向け、240x160 → 128x85）: `GBA-style pixel art character bust-up for 128x85 screen. True pixel art, crisp 1px edges, no anti-aliasing, no gradients, 256-color palette, optional subtle dithering.`
  - 例（汎用）: `16-bit pixel art style, limited color palette, no anti-aliasing, clean pixel edges`
  - 例（日本語）: 「GBA RPG風ピクセルアート、限定パレット、アンチエイリアスなし、ドット絵」
- 設定ファイルが指定されている場合は、Step 1と同様にその全文をプロンプトに含める
- **generate-imageスキルに `-m gemini-3-pro-image-preview -s 1K` を必ず指定すること**
- **出力先は `/tmp` 配下にすること**（例: `/tmp/pixelart_step2.png`）
- 出力ファイルパスを控えておく（Step 2.5で使用）

### Step 2.5: グリーン背景の単一色統一（ImageMagick）

AI生成画像はグリーン背景を指定してもピクセルごとに微妙な色ブレが生じる。ppa変換前にグリーン系のピクセルを完全な単一色 `#00FF00` に統一しておくことで、変換後の背景色ムラを防ぐ。

```bash
convert <step2-output> -fuzz 35% -fill '#00FF00' -opaque '#00FF00' <unified-output>
```

- `-fuzz 35%` でグリーンに近い中間色も含めて `#00FF00` に統一する。前景のグリーン系の色まで置換されてしまう場合は値を下げて調整する
- **出力先は `/tmp` 配下にすること**（例: `/tmp/pixelart_step2_unified.png`）
- 出力ファイルパスを控えておく（Step 3で使用）

### Step 3: true pixel art変換

proper-pixel-artでダウンサンプル＋量子化を行い、true pixel artに変換する。

```bash
uvx --from proper-pixel-art ppa <unified-output> -o <final-output> -c <colors> -w <pixel-width> -u 1
```

- `-c`: 量子化色数（デフォルト256、GBA BG向けなら256、GBAスプライト向けなら16など用途に応じて調整）
- `-w`: **入力画像の1ドット幅を手動指定する（必須）**。AI生成のドット絵風画像はクリーンなピクセルグリッドを持たないため、自動検出では正しいドット幅を判定できない。`入力画像の幅 / 目標解像度の幅` で計算する（例: 1K画像(1264px幅)でGBA BG 240px幅を狙う場合、`1264 / 240 ≈ 5` → `-w 5`）
- `-u 1`: **初期アップスケールを無効化する（必須）**。デフォルトでは入力画像が2倍にアップスケールされてから `-w` が適用されるため、`-u 1` を指定しないと出力サイズが想定の2倍になる
- 最終出力はユーザー指定のパスまたはカレントディレクトリに出力する

#### 結果確認

出力画像をReadツールで目視確認し、ユーザーに結果を伝える。

## 全体の使用例

### GBA RPG風バストアップの場合

1. generate-imageスキルで高品質イラストを `/tmp/pixelart_step1.png` に生成（アスペクト比 3:2）
2. generate-imageスキルでStep 1の出力を参照し「GBA RPG風ピクセルアート、128x85スクリーン向け、限定パレット、アンチエイリアスなし」で `/tmp/pixelart_step2.png` に再生成（目標240x160だが、プロンプトには長辺128px上限の128x85を指定）
3. ImageMagickでグリーン背景を単一色に統一:
   ```bash
   convert /tmp/pixelart_step2.png -fuzz 35% -fill '#00FF00' -opaque '#00FF00' /tmp/pixelart_step2_unified.png
   ```
4. proper-pixel-artでダウンサンプル＋量子化（1264/240≈5 → `-w 5`、`-u 1`で初期アップスケール無効化）:
   ```bash
   uvx --from proper-pixel-art ppa /tmp/pixelart_step2_unified.png -o final.png -c 256 -w 5 -u 1
   ```
5. Readツールで `final.png` を目視確認

### GBA キャラクターBG（縦長→正方形切り出し）パターン

キャラクターのバストアップBGを作る場合、1:1で生成するとキャラが小さくなりドット絵変換時に潰れやすい。
**9:16の縦長で生成→ppa変換→頭頂部基準で正方形に切り出し** することで、キャラを大きく描画できる。

1. Step 1: generate-imageスキルで **`-a 9:16`** で縦長イラストを生成（グリーンバック）
2. Step 2: Step 1を参照画像としてドット絵風に再生成（同じく `-a 9:16`）
3. Step 2.5: グリーン背景を統一
4. Step 3: ppa変換。**`-w` は1:1の場合と同じ値を使う**（例: 1:1で `-w 4` なら縦長でも `-w 4`）
   - 768x1376 の入力に `-w 4` → 192x344 の出力になる
5. **切り出し**: ImageMagickで頭頂部基準に正方形（256x256）で切り出す。幅が足りない場合はグリーンで拡張する:
   ```bash
   convert <step3_full.png> -background '#00FF00' -gravity North -extent 256x256 <step3.png>
   ```
   - `-gravity North` で画像上部（頭）を基準に切り出す
   - 幅が256に満たない場合は左右にグリーンが補填される（キャラは中央配置）
6. BMP3変換:
   ```bash
   convert <step3.png> -type Palette BMP3:<output.bmp>
   ```

**このパターンを使うべき場面:**
- グリーンバック付きキャラクターBG（バストアップ等）
- 最終出力が正方形（256x256）だがキャラを大きく描きたい場合

**使わなくてよい場面:**
- 全画面イラスト → 最初から1:1で生成
- 背景BG（風景のみ）→ 1:1で生成
- スプライト → 下記の一括生成パターンを使用

### GBA スプライト一括生成パターン

複数のスプライトを1枚の画像にまとめて生成し、切り出し後に個別にppa変換する。
デザインの統一感を保つために、関連するスプライトは可能な限り1枚にまとめて生成する。

1. **Step 1**: generate-imageスキルで**全スプライトを1枚の画像に並べて生成**する
   - プロンプトに各スプライトの内容・配置を明記する（例: 「左から順に: グーカード、チョキカード、パーカード」）
   - グリーンバック(`#00FF00`)を指定
   - アスペクト比はスプライトの配置に合わせて選択（横並びなら横長）
2. **Step 2**: Step 1を参照画像としてドット絵風に再生成（同じアスペクト比）
3. **Step 2.5**: グリーン背景を単一色に統一
4. **切り出し**: ImageMagickで各スプライトを個別に切り出す
   ```bash
   # 例: 1264x768の画像から3つのスプライトを切り出し
   convert <step2_unified.png> -crop 420x768+0+0 +repage /tmp/sprite1_cut.png
   convert <step2_unified.png> -crop 420x768+422+0 +repage /tmp/sprite2_cut.png
   convert <step2_unified.png> -crop 420x768+844+0 +repage /tmp/sprite3_cut.png
   ```
   - 切り出し位置は `identify -verbose` や目視で確認する
   - 左右反転が必要なスプライトには `-flop` を追加する
5. **Step 3**: 切り出した各画像に対して個別にppa変換する
   ```bash
   uvx --from proper-pixel-art ppa /tmp/sprite1_cut.png -o /tmp/sprite1_ppa.png -c 16 -w <pixel-width> -u 1
   ```
   - `-c 16`: GBAスプライトは4bpp（16色）
   - `-w`: `切り出し画像の幅 / 目標スプライト幅` で計算
6. **BMP3変換**: 各スプライトをBMP3 4bppに変換
   ```bash
   convert <ppa.png> -type Palette -colors 16 BMP3:<output.bmp>
   ```
7. **パレットindex 0修正（必須）**: ImageMagickの`-colors 16`量子化ではパレットの並び順が保証されず、index 0が`#00FF00`にならないことが多い。GBAスプライトではindex 0が透過色として扱われるため、**BMP3変換後に必ずパレットindex 0を`#00FF00`に修正すること**。

   ```python
   import struct

   def fix_sprite_palette_index0(bmp_path):
       with open(bmp_path, 'rb') as f:
           data = bytearray(f.read())

       w = struct.unpack_from('<i', data, 18)[0]
       h = abs(struct.unpack_from('<i', data, 22)[0])
       bpp = struct.unpack_from('<H', data, 28)[0]
       data_offset = struct.unpack_from('<I', data, 10)[0]
       n_colors = 1 << bpp

       # Read palette and find green
       pal = []
       for i in range(n_colors):
           off = 54 + i * 4
           b, g, r = data[off], data[off+1], data[off+2]
           pal.append((r, g, b))

       green_idx = next((i for i, c in enumerate(pal) if c == (0, 255, 0)), None)
       if green_idx is None:
           # Find closest to green
           green_idx = min(range(n_colors), key=lambda i: pal[i][0]**2 + (255-pal[i][1])**2 + pal[i][2]**2)

       if green_idx == 0:
           # Already at 0, ensure exact value
           data[54], data[55], data[56] = 0, 255, 0
       else:
           # Swap palette entries
           old0 = pal[0]
           data[54], data[55], data[56], data[57] = 0, 255, 0, 0
           offg = 54 + green_idx * 4
           data[offg], data[offg+1], data[offg+2], data[offg+3] = old0[2], old0[1], old0[0], 0

           # Swap pixel indices (4bpp packed: high nibble = even col, low nibble = odd col)
           row_bytes = (w * bpp + 31) // 32 * 4
           for row in range(h):
               row_start = data_offset + row * row_bytes
               for col in range(w):
                   byte_off = row_start + col // 2
                   hi = (data[byte_off] >> 4) & 0x0F
                   lo = data[byte_off] & 0x0F
                   if col % 2 == 0:
                       if hi == 0: hi = green_idx
                       elif hi == green_idx: hi = 0
                       data[byte_off] = (hi << 4) | lo
                   else:
                       if lo == 0: lo = green_idx
                       elif lo == green_idx: lo = 0
                       data[byte_off] = (hi << 4) | lo

       with open(bmp_path, 'wb') as f:
           f.write(data)
   ```

   この関数を全スプライトBMPに対して実行する。省略するとGBA上でスプライトの透過が効かず、緑色の矩形が表示される。

**一括生成の判断基準:**
- 同じカテゴリのスプライト（例: グー・チョキ・パーのカード）→ 必ずまとめる
- 同じゲーム内で使うスプライト全般 → できるだけまとめる（1枚に7〜8個程度まで）
- サイズが大きく異なるスプライトが混在しても問題ない（切り出し後に個別リサイズ）

## 依存ツール

- `convert` (ImageMagick) — 背景色の単一色統一
- `uvx` (uv) — proper-pixel-artの実行

## エラー時の対応

- Step 1/2で画像が生成されない → プロンプトを変更して再試行
- Step 2.5で前景のグリーン系の色まで置換される → `-fuzz` 値を下げて調整
- Step 2.5で背景色の統一が不要 → ステップをスキップ
- proper-pixel-artが見つからない → `uvx --from proper-pixel-art ppa --help` で確認
