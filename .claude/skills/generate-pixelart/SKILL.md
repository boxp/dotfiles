---
name: generate-pixelart
description: ドット絵・ピクセルアートを生成。「ドット絵を生成」「ピクセルアートを作って」「GBA用の画像を作って」「Even G2 用の単色ドット絵」時に使用
argument-hint: "<プロンプトまたは説明>"
---

# ドット絵・ピクセルアート生成スキル

AI 画像生成 → ドット絵風再生成（候補複数）→ 論理グリッドへの snap → パレット整理 → pixel cleanup →
機械検査＋目視の品質 gate、でピクセルパーフェクトなドット絵を作る。

「ピクセルパーフェクト」は 2 つの意味を両方満たすこと:
1. **機械的な正しさ**: 1 ドット = 1 px の原寸 PNG、alpha は 0/255、色数はパレット内、整数倍 nearest 拡大で崩れない
2. **画素配置の美術品質**: clean な pixel cluster、意図した輪郭の step、原寸で顔・視線・シルエットが読める

高解像度イラストの nearest 縮小・減色・モザイク、`ppa` 通過だけでは完成としない。

## 引数
- `$ARGUMENTS`: 生成したいドット絵の説明（日本語可）

## 支援 script

`scripts/` 配下。すべて `uv run <script>` で実行する（PEP 723 で Pillow/numpy を自動解決。ImageMagick 不要）。

| script | 役割 |
| --- | --- |
| `pixel_snap.py` | AI 生成のドット絵風画像をドット格子に snap して原寸化。`--grid auto` で実際のドット幅を推定 |
| `pixel_cleanup.py` | キー色透過、縁 fringe 除去、飛び地除去、孤立 pixel 整理（ハイライト保護）、canvas 配置 |
| `pixel_palette.py` | 色数量子化 / 固定パレット / preset（`g2-green16`）への写像 |
| `pixel_check.py` | 寸法・色数・alpha・fringe・孤立率・整数倍整合・差分漂流・コントラストの機械検査（違反で exit 1） |
| `pixel_composite.py` | 表情差分: 目・口の矩形だけを基準画像へ合成し、それ以外の漂流を封じる |
| `pixel_preview.py` | 原寸と整数倍 nearest の比較シート、G2 画面（576x288 黒）の preview |

テスト: `bash tests/run-tests.sh`（正例と違反 fixture の両方を検査）。

## 中間ファイルと記録

- Step 1〜5 の中間ファイルは作業ディレクトリ（例: `/tmp/pixelart-<name>/`）に置き、最終出力だけをユーザー指定先へ出す
- 各生成について **プロンプト全文・model・サイズ・出力の sha256** を `manifest.txt` に残す。
  `generate-image` の API 呼び出しは seed を受け付けず出力は非決定的なので、「同じ設定で再生成しても同じ絵は出ない」ことを前提に候補画像そのものを保存する
- 公開 PR やノートに private の原典画像・原典プロンプトを載せない（生成物と計測値のみ）

## Step 0: 仕様を先に固定する

`templates/brief.md` を埋めてから生成を始める。最低限:

- 用途と **実表示サイズ**（例: 64x64 を 1x と 4x で表示。CSS px や device px との一致は保証しない）
- **論理 pixel grid**（canvas）と anchor（例: 80x80、頭頂を上端基準で中央配置）
- パレット上限（例: 24 色）と dither の可否
- 輪郭（外側 1px 暗色、内側は色境界のみ、など）、光源（左上、影 1 段 + ハイライト 1 段）
- 透過（キー色 `#00FF00` → alpha 0/255）と背景の有無
- キャラ・ポーズ・framing（頭頂〜どこまで入れるか）。設定ファイルがあれば全文をプロンプトに含める（要約禁止）
- 差分がある場合: 差分で変えてよい部位（目・眉・口）とそれ以外は固定

## Step 1: 参照イラスト生成

`generate-image` skill で高品質なイラストを 1 枚作る。これが全候補・全差分の共通参照になる。

- 背景は単色 `#00FF00`、ポーズ・framing・光源を brief どおり明示、「no text」
- 本票の検証では `-m gemini-3-pro-image -s 1K`（1024x1024）を使った。他 model は未検証であり、使う場合は Step 3 の実測ピッチで判断する
- 例: `bb ~/.claude/skills/generate-image/generate-image.bb -m gemini-3-pro-image -s 1K -a 1:1 -o work/step1_base.png "<prompt>"`

## Step 2: ドット絵風の再生成（候補を 2〜3 枚）

Step 1 を参照画像にして、ドット絵風の画像を **同じプロンプトで 2〜3 枚** 作る（出力は非決定的なので候補比較が必要）。

プロンプトの骨子（英語推奨）:

```
Redraw this exact character as true low-resolution pixel art on a <N>x<N> pixel grid, shown scaled up so that
every pixel is a large, crisp, perfectly square block of uniform color (each block is 1/<N> of the image width).
Hand-placed pixel clusters in the style of 16-bit RPG portrait sprites: flat solid colors, no gradients,
no dithering, no anti-aliasing, no blur. Palette of at most <C> colors with one shadow tone and one highlight
tone per material, light from <光源>. Dark 1px outline only around the silhouette and major shape boundaries.
Keep the face readable: eyes are 2-3 pixel clusters with a single highlight pixel, mouth is a short line.
Same pose, framing, hair and clothing as the reference. Solid flat pure green background #00FF00, nothing else.
```

**プロンプトの grid 数 `<N>` は目安でしかない。** 実際のドット幅は Step 3 で必ず実測する。
本票の較正（gemini-3-pro-image 1K 1:1、同一参照）:

| プロンプトで指定した grid | 実測ドット幅 (px) | 実際の格子 |
| --- | --- | --- |
| 64x64 | 5.1〜7.3 | 140〜200 |
| 32x32 | 10.25 | 100 |
| 20x20 | 12.8 | 80 |
| 16x16 | 10.25 | 100（下限に張り付く） |

つまり 1K 出力ではおおむね **80〜100 格子が下限**。目標 canvas が 64 程度なら、framing を寄せて（顔だけ等）
80〜100 格子で生成し、Step 4 で **切り出し**（再サンプルなし）で canvas に収める。
目標が 128〜200 なら grid 指定 32〜64 で狙う。

## Step 3: 格子に snap して原寸にする（候補ごと）

```bash
uv run scripts/pixel_snap.py work/step2_c1.png -o work/snap_c1.png --grid auto --report work/snap_c1.json
```

- `--grid auto` は色変化の自己相関からドット幅を推定し、cell 内の色が最も均一になるピッチと位相を探す。
  `report` の `grid`（実際の格子数）と `cell_variance`（小さいほど格子が合っている。名目値 `cell_variance_nominal` より明確に小さいこと）を見る
- 実測格子が目標 canvas と **±15% 以内** なら `--grid WxH` で目標格子に snap してよい。それ以上ずれるなら
  (a) Step 2 の grid 指定を変えて再生成、(b) 実測格子を採用して canvas を見直す、(c) 切り出しで収める、のどれかを選ぶ。
  **目標格子に合わせるためだけに `--grid` で粗い格子を押し付けると、AI が置いた cluster が潰れる（単なる縮小になる）ので不可**
- 各 cell の色は内側 50% 領域の最頻色（`--method mode`）。縁の blur を拾わない
- 周期が検出できない（`Error: ドット格子の周期を検出できない`）画像は、ドット絵風になっていない。候補から外す

旧手順の `uvx --from proper-pixel-art ppa` は格子の位相を合わせられず、`-w` 固定でも出力寸法が目標と一致しない
（本票の実測: 64 目標で 69x73 / 65x69）ため、使わない。

## Step 4: 透過・パレット・cleanup

```bash
# 1) キー色を透過、緑に寄った縁を周囲色で置換、3px 未満の飛び地を除去
uv run scripts/pixel_cleanup.py work/snap_c1.png -o work/key_c1.png --key '#00FF00' --key-tol 100 --defringe 140 --min-island 3
# 2) パレット（色数上限）に揃える。dither 無しの median cut
uv run scripts/pixel_palette.py work/key_c1.png -o work/pal_c1.png --colors 24
# 3) 孤立 pixel を周囲の最頻色に置換。周囲より明るい点（目のハイライト等）は保護
uv run scripts/pixel_cleanup.py work/pal_c1.png -o work/c1.png --despeckle --protect-bright
# 4) 必要なら canvas に配置（縮小はしない。入らなければ error）
uv run scripts/pixel_cleanup.py work/c1.png -o work/c1_canvas.png --trim --canvas 80x80 --anchor top
```

- 孤立 pixel や AA を無条件で禁止しない。`--protect-bright` と `--protect '#rrggbb'` で光点・表情の 1px を残す。
  それでも消えた意図的な点は Step 5 の目視で見つけ、`--protect` を足して再実行する
- 固定パレットで揃えたい場合は `--palette '#..,#..'` またはパレットファイルを使う

## Step 5: 品質 gate（機械検査 ＋ 目視）

```bash
uv run scripts/pixel_check.py work/c1_canvas.png --expect-size 80x80 --max-colors 24 --key '#00FF00' \
    --max-isolated 0.02 --json work/check_c1.json
uv run scripts/pixel_preview.py -o work/compare.png --scales 1,4 --bg '#404040' c1=work/c1_canvas.png c2=work/c2_canvas.png
```

機械検査（1 つでも違反なら不合格、exit 1）:
- 寸法が canvas と一致、色数が上限内、alpha が 0/255 のみ（halo 無し）、縁にキー色寄りの fringe 無し
- 孤立 pixel 比率 ≤ 2%（不透明 pixel に対する）。保護した光点は含まれてよい
- 配布用に整数倍拡大した PNG は `--scale N` で全ブロックが単色であることを確認する

目視（比較シートを Read で開き、**原寸 1x と 4x の両方**で見る）:
- 原寸で顔・視線・シルエット・髪/衣装が識別できるか。細部を詰めすぎて潰れていないか
- 輪郭の step が意図どおりか（ガタつき、不要な AA、1px の細切れ線）
- banding（近い色の帯）、pillow shading（輪郭に沿った同心の明暗）、不規則な pixel 密度の有無
- 光源の一貫性（影とハイライトの向き）

判定:
- 候補のうち機械検査を通り目視で最良のものを採用。全候補が不合格なら Step 2 を **最大 2 回**まで再生成（プロンプトの grid 指定や framing を変える）
- それでも不合格なら「不合格」として候補画像と検査 JSON を添えて報告する。合成や縮小で合格に見せない
- PNG の完成（機械検査合格）と、美術品質の受入（人の好み）は分けて報告する

## Step 6: 表情差分

1. 採用した候補の **Step 2 画像**（ドット絵風、1K）を参照に、「表情以外は変えない」指示で差分を生成する
   ```
   Keep this pixel art portrait exactly as it is: same pixel grid, same palette, same pose, framing, hair,
   clothing, lighting and outline style. Change ONLY the facial expression to: <表情>. Do not move or redraw
   anything outside the eyes, eyebrows and mouth.
   ```
2. 基準と **同じ格子**で snap する: `pixel_snap.py var.png -o snap_var.png --like work/snap_c1.json`
3. 基準のパレットに揃える: `pixel_palette.py ... --palette <基準の色一覧>`（`pixel_check.py --json` の出力から作るか、
   `python -c` で基準画像の不透明色を列挙）
4. **AI は「表情だけ」と頼んでも全体を描き直す**（本票の実測: 変化 pixel 17〜28%、髪や衣装の形も動く）。
   目・眉・口を含む矩形だけを基準へ合成する:
   `pixel_composite.py base.png var.png -o final_var.png --region x0,y0,x1,y1`
5. 漂流検査: `pixel_check.py final_var.png --compare base.png --max-drift 0.1` と、差分シートの目視（表情が読めるか、
   矩形の境目に継ぎ目が出ていないか）

## Profile: Even G2 向け green 16 階調（`g2-green16`）

G2 は 576x288 px の単色 green 16 階調、image container は ≤288x144、**黒 (level 0) は透過**として扱う。
カラー絵を無検証で grayscale 化すると、暗い髪や輪郭が level 0 に落ちて背景に溶ける。

```bash
uv run scripts/pixel_palette.py work/c1_canvas.png -o work/c1_g2.png --preset g2-green16 --stretch 2,98 --gamma 0.8 --floor 3
uv run scripts/pixel_check.py work/c1_g2.png --preset g2-green16 --min-contrast 100
uv run scripts/pixel_preview.py -o work/g2_preview.png --g2 face=work/c1_g2.png
```

- `--floor N`: 不透明 pixel の最低 level。`--floor 0` は「不透明なのに消える」pixel を生み `pixel_check --preset` が拒否する。
  意図的に level 0 を使う場合だけ `--allow-opaque-transparent-level` を付け、仕様に明記する
- `--stretch` で輝度の percentile を 0〜15 に引き伸ばし、`--gamma < 1` で中間調を持ち上げる
- 目視は **G2 preview（黒背景・原寸）** で、髪の塊と顔、輪郭とシルエットが分離して読めるかを見る。
  低コントラストなら `--floor` と `--gamma` を調整し、改善しなければカラー側のパレットを見直す
- 検証では AI に直接「単色 green のドット絵」を描かせると格子が不均一（周期検出不能〜不整合）になった。
  **カラー版を作ってから preset で変換する**手順を標準とする
- 実機表示は SDK 送信の成功と一致しない（BOXP-315 の設計前提）。ここでの preview は目安であり実機確認は別

## 使用例（本票の検証で実行した流れ）

1. brief を固定（顔グラ、canvas 80x80 → 64x64 切り出し、24 色、キー色 `#00FF00`）
2. Step 1 で参照イラスト 1 枚（1K 1:1）
3. Step 2 で grid 20 指定の候補を生成、`--grid auto` で実測 80x80 を確認
4. Step 4〜5 で透過・24 色・despeckle → 検査 OK（80x80、23 色、alpha 0/255、孤立率 0.6%）
5. Step 6 で驚き・笑いの 2 差分を生成、`--like` で同格子 snap、顔矩形 `20,26,62,52` を合成 → 漂流 5〜7%
6. `g2-green16` preset に変換し、G2 preview で可読性を確認

## 関連 reference

- `references/gba.md`: GBA 向け BG/スプライト（BMP3、パレット index 0、縦長切り出し、一括生成）の手順。
  旧手順の `ppa` 依存部分は Step 3〜4 に置き換えて読むこと
- `templates/brief.md`: 仕様テンプレ

## 依存ツール

- `uv`（`uv run` で Pillow/numpy を自動取得）
- `bb` と `generate-image` skill（`GEMINI_API_KEY`）
- ImageMagick は不要（GBA の BMP3 変換を行う場合のみ `convert` を使う）

## エラー時の対応

- 画像が生成されない → プロンプトを変えて再試行。設定ファイルの全文を含めているか確認
- `pixel_snap.py` が周期を検出できない → その候補はドット絵風になっていない。候補から外すか Step 2 を再生成
- 実測格子が目標から大きく外れる → Step 2 の grid 指定・framing を変える。`--grid` で無理に合わせない
- `pixel_cleanup.py` で `内容が canvas より大きい` → 縮小はしない。canvas を見直すか、framing を寄せて再生成
- 検査の fringe 違反 → `--defringe` の値を上げる。前景に緑系の色がある場合は `--key-tol` を下げる
- 光点や表情の 1px が despeckle で消えた → `--protect '#rrggbb'` を足して再実行
