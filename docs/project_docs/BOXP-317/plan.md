# BOXP-317: generate-pixelart skill の画素品質改善 計画

## 目的

既存の `generate-pixelart` skill（正本: `.claude/skills/generate-pixelart/SKILL.md`）は
「Nano Banana Pro でイラスト生成 → ドット絵風に再生成 → 背景色統一 → `ppa` でグリッド化」の手順書で、
出力の機械的な検査も、候補比較も、pixel cleanup も持たない。
出力は「減色した縮小イラスト」に近く、孤立ノイズ・不規則な画素密度・意図しない AA が残る。
ピクセルパーフェクトなドット絵を生成する目的はそのままに、手順と支援ツールを改良する。

## 現行の問題（実物で確認）

BOXP-276 で現行手順により生成した顔グラ（144x144、47 色）と旧 64x64 版を実測・目視した。

- 孤立 pixel・1px の細切れ線が髪・衣装に多く、clean な pixel cluster になっていない
- `ppa` の自動検出・`-w` 固定のどちらも AI 生成画像の「ゆらいだグリッド」に対して位相を合わせられず、ドット幅が不揃いになる
- 色数は `-c` の上限で決まるだけで、意図したパレット（ramp）にならない。近い色が多数並び banding になる
- 透過は緑キー色の fuzz 置換に依存し、縁の fringe（緑がかった輪郭）の検査が無い
- 目視確認は「Read で見る」だけで、原寸と整数倍の両方で確認する手順も、不合格時の再試行基準も無い
- Even G2 向け単色出力の preset が無い

## 方針

1. 生成経路は既存承認済みの `generate-image` skill（Gemini、`GEMINI_API_KEY`）のみを使う。特定 model を無根拠に必須化しない。
2. 支援 script は Pillow + numpy の Python（PEP 723 inline metadata、`uv run` で実行）。
   bb には画像 I/O が無く、ImageMagick は codex-workspace に無いため、この用途では Python が自然。
   `ppa` 自体も Python であり、既存 skill も Python snippet を含む。
3. 手順を「仕様固定 → 生成 → 候補比較 → グリッド snap → パレット → cleanup → 機械検査 ＋ 目視 → 再試行/不合格」の品質 gate にする。
4. 汎用カラー pixel-art を維持し、Even G2 用の green 16 階調 / 黒 transparent / ≤288x144 を別 preset にする。
5. 旧版と新版を同じ合成 brief・同じ canvas で実生成し、原寸と整数倍 nearest で比較する。Kohako 原典は外部送信しない。

## 成果物

- `.claude/skills/generate-pixelart/SKILL.md`: 品質 gate 付きの手順
- `scripts/pixel_snap.py`: AI 生成ドット絵風画像を論理グリッドへ snap（位相・ピッチ推定、cell 内 mode/center 抽出）
- `scripts/pixel_palette.py`: 固定色数 / パレットファイル / preset（`g2-green16`）への量子化
- `scripts/pixel_cleanup.py`: キー色透過、縁 fringe 除去、孤立 pixel 整理（明部ハイライトの保護あり）
- `scripts/pixel_check.py`: 寸法・色数・alpha 離散性・fringe・孤立 pixel 比率・整数倍整合・差分漂流の機械検査（JSON、非 0 exit）
- `scripts/pixel_preview.py`: 原寸と整数倍 nearest の比較シート、G2 の黒背景 preview
- `templates/brief.md`: 用途 / 表示サイズ / 論理 grid / パレット / 輪郭 / 光源 / 透過 / 背景の仕様テンプレ
- `references/gba.md`: 旧 SKILL.md の GBA 向け手順（内容は維持）
- `tests/run-tests.sh`: 正例・違反 fixture の両方で check が期待どおり pass/fail することを確認
- `.github/workflows/generate-pixelart.yml`: 上記テストを CI で実行

## 検証

- 合成 brief（非 private のオリジナルキャラ）で、小型顔グラ・表情差分 2 種・G2 向け単色 preset を旧版/新版で生成
- 比較画像と実測値（色数 / alpha / 寸法 / 孤立 pixel 比率）を Obsidian `Projects/pixel-art-skill-improvement/` に保存
- PR → CI → merge → codex-workspace の dotfiles-sync（origin/master ff + setup.sh）で導入されたことを readback
- 美術品質の受入は Owner 判断として残す

## 追加（2026-10-26、Owner 追加要望: 他 AI 方式の比較調査）

### 目的

既存 pipeline の局所改善で方式を固定せず、専用 pixel-art 生成（PixelLab / Retro Diffusion）、汎用 model + 後処理、
ローカル model / LoRA、hybrid（AI + pixel 単位編集）を一次資料で比較し、承認済み経路で実測できる候補は同一 brief で比較して
skill に反映する。

### 方針

1. 新規契約・課金・credential 取得・私的資料の新規送信・共有 pod の重い GPU/CPU 実験はしない。実測は Gemini 経路と OSS 後処理のみ
2. 机上評価は公式 docs / 規約 / 独立した第三者の実例に限り、ベンダー宣伝や affiliate 比較は独立評価と扱わない
3. 同一参照イラスト・同一 brief・同一論理解像度・各方式 2〜3 sample で比較し、機械検査だけで優劣を決めない

### 成果物（本 PR）

- `generate-image.bb` に `-S/--seed`（`generationConfig.seed`）を追加。flash で近い構図の再現を実測（完全一致ではない）
- `generate-pixelart/SKILL.md`: gemini-3.1-flash-image の較正表、`-s 512` と格子線参照・AI 自己修正が効かなかった実測、`unfake` との比較、seed の扱い
- `generate-pixelart/references/method-comparison.md`: 方式比較の要約と推奨・乗り換え条件
- 詳細（出典 URL・比較画像・検査 JSON）は Obsidian の Projects/pixel-art-skill-improvement/ に置き、公開 PR には載せない
