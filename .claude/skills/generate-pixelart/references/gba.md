# GBA 向け手順（旧 SKILL.md から移設）

ドット絵化は SKILL.md の Step 2〜5（候補生成 → `pixel_snap.py --grid auto` → `pixel_cleanup.py` /
`pixel_palette.py` → `pixel_check.py`）で行う。旧手順の `convert -fuzz` による背景統一と `ppa` 変換は使わない
（格子の位相が合わず出力寸法が目標と一致しないため）。以下では `PX=~/.claude/skills/generate-pixelart/scripts`。
BMP3 変換には ImageMagick (`convert`) が必要。

GBA 向けの共通パイプライン（1 枚分。`<COLORS>` は BG なら 256、スプライト (4bpp) なら 16）:

```bash
uv run $PX/pixel_snap.py step2.png -o snap.png --grid auto --report snap.json      # 実測格子で原寸化
uv run $PX/pixel_cleanup.py snap.png -o key.png --key '#00FF00' --key-tol 100 --defringe 140 --min-island 3
uv run $PX/pixel_palette.py key.png -o pal.png --colors <COLORS>                  # BG は 256、スプライトは 16
uv run $PX/pixel_cleanup.py pal.png -o art.png --despeckle --protect-bright
uv run $PX/pixel_check.py art.png --max-colors <COLORS> --key '#00FF00' --max-isolated 0.02
```

実測格子が目標（BG 240x160、スプライト 32x32 など）と合わない場合は Step 2 の grid 指定・framing を変えて再生成する。
`--grid` で無理に目標格子へ押し込まない。BMP3 化の前に `pixel_cleanup.py --trim --canvas WxH --anchor top` で
目標 canvas に配置し、透過部をキー色 `#00FF00` に戻す（下記）。

### GBA RPG風バストアップの場合

1. generate-imageスキルで高品質イラストを `/tmp/pixelart_step1.png` に生成（アスペクト比 3:2）
2. generate-imageスキルでStep 1の出力を参照し「GBA RPG風ピクセルアート、128x85スクリーン向け、限定パレット、アンチエイリアスなし」で `/tmp/pixelart_step2.png` に再生成（目標240x160だが、プロンプトには長辺128px上限の128x85を指定）
3. 共通パイプライン（上記）で snap → cleanup → `--colors 256` → check。実測格子が 240x160 付近になるまで Step 2 を調整
4. `pixel_preview.py` の比較シートを Read で原寸と整数倍の両方で目視確認

### GBA キャラクターBG（縦長→正方形切り出し）パターン

キャラクターのバストアップBGを作る場合、1:1で生成するとキャラが小さくなりドット絵変換時に潰れやすい。
**9:16の縦長で生成→snapで原寸化→頭頂部基準で正方形に切り出し** することで、キャラを大きく描画できる。

1. Step 1: generate-imageスキルで **`-a 9:16`** で縦長イラストを生成（グリーンバック）
2. Step 2: Step 1を参照画像としてドット絵風に再生成（同じく `-a 9:16`）
3. 共通パイプライン（上記）で snap → cleanup → パレット → check
4. **切り出し**: 頭頂基準で 256x256 に配置する（縮小はしない。入らなければ Step 2 の grid 指定を見直す）:
   ```bash
   uv run $PX/pixel_cleanup.py art.png -o step3.png --trim --canvas 256x256 --anchor top
   ```
5. 透過部をキー色に戻す（BMP3 はパレット index 0 で透過を表すため）:
   ```bash
   convert step3.png -background '#00FF00' -alpha remove -alpha off step3_green.png
   ```
6. BMP3変換:
   ```bash
   convert step3_green.png -type Palette BMP3:<output.bmp>
   ```

**このパターンを使うべき場面:**
- グリーンバック付きキャラクターBG（バストアップ等）
- 最終出力が正方形（256x256）だがキャラを大きく描きたい場合

**使わなくてよい場面:**
- 全画面イラスト → 最初から1:1で生成
- 背景BG（風景のみ）→ 1:1で生成
- スプライト → 下記の一括生成パターンを使用

### GBA スプライト一括生成パターン

複数のスプライトを1枚の画像にまとめて生成し、切り出し後に個別に cleanup・パレット・検査する。
デザインの統一感を保つために、関連するスプライトは可能な限り1枚にまとめて生成する。

1. **Step 1**: generate-imageスキルで**全スプライトを1枚の画像に並べて生成**する
   - プロンプトに各スプライトの内容・配置を明記する（例: 「左から順に: グーカード、チョキカード、パーカード」）
   - グリーンバック(`#00FF00`)を指定
   - アスペクト比はスプライトの配置に合わせて選択（横並びなら横長）
2. **Step 2**: Step 1を参照画像としてドット絵風に再生成（同じアスペクト比）
3. **snap**: 1 枚全体を `pixel_snap.py --grid auto` で原寸化する（スプライト間で格子が共通になる）
4. **切り出し**: 原寸化した画像から各スプライトを個別に切り出す（ImageMagick `-crop`、または Pillow）。
   切り出し位置は目視で確認し、左右反転が必要なスプライトには `-flop` を追加する
5. **cleanup・パレット・検査**: 切り出した各画像に共通パイプラインの cleanup → `--colors 16` → check を個別に適用し、
   `--trim --canvas WxH` で目標スプライト寸法に配置、透過部をキー色に戻す（上記 `-alpha remove`）
6. **BMP3変換**: 各スプライトをBMP3 4bppに変換
   ```bash
   convert <sprite_green.png> -type Palette -colors 16 BMP3:<output.bmp>
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

