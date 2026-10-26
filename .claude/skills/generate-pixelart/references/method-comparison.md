# ドット絵生成方式の比較と、この skill が Gemini 経路を採る根拠（2026-10-26 時点）

公開一次資料（参照日 2026-10-26）と、同一 brief・同一参照イラスト・同一論理解像度での実測に基づく。
詳細な出典・比較画像・検査 JSON は Obsidian の Projects/pixel-art-skill-improvement/method-comparison.md にある。
**未試行の候補は「低品質」と断定していない。** 実測したのは承認済み経路（Gemini API）と OSS 後処理のみ。

## 候補の系統

| 系統 | 候補 | 本 skill との関係 |
| --- | --- | --- |
| 専用 pixel-art 生成サービス | PixelLab（pixellab.ai）、Retro Diffusion（retrodiffusion.ai） | 未試行（account / API key 無し）。机上評価 |
| 汎用画像 model + grid 復元 + cleanup | Gemini（本 skill）、GPT Image、Midjourney、Recraft、Stability、FLUX.2、Seedream、Qwen-Image | Gemini のみ実測。他は机上 |
| ローカル model / LoRA | SDXL + pixel-art-xl、FLUX.2 klein-4B + svntax pixel LoRA、Z-Image / Qwen-Image pixel LoRA | 未試行（GPU 無し） |
| hybrid（AI + pixel 単位編集） | AI 自己修正、script cleanup（本 skill）、Aseprite / LibreSprite / Pixelorama headless、OSS 後処理（unfake、perfect-pixel、spritefusion-pixel-snapper、PixelOE） | 自己修正と unfake は実測 |

## 実測（Gemini 経路、同一条件）

| 方式 | 実測格子 | 最終 | 色数 | 孤立率 | 目視 |
| --- | --- | --- | --- | --- | --- |
| 参照イラストの nearest 縮小 + 24 色（生成 0 回） | - | 80x80 | 23 | 0.70% | 泥状、輪郭途切れ。機械検査は通るがドット絵ではない |
| 旧 skill（pro-image「pixel art style」→ ppa -w16）×2 | 200〜250 | 68x74 / 70x68 | 19 | 0.2% | 目標格子に不一致、髪色が転ぶ sample あり |
| 新 pipeline、gemini-3-pro-image、grid 20 | 80 | 80x80 | 23 | 0.34% | 顔・視線が読める。髪の暗線が細切れの箇所あり |
| 新 pipeline、gemini-3.1-flash-image、grid 20 ×3 | 100 / 100 / 非等方 | 100x100 | 22〜23 | 0.1% | 最も clean な cluster と一貫した輪郭 step。初回採用率 2/3 |
| flash、grid 12 | 72 | 72x72 | 21 | 0.23% | 髪の内側が荒れる |
| flash、`-s 512`、grid 20 | 104 | - | - | - | 格子数は下がらない |
| flash + 20x20 格子線を 2 枚目参照 | 非等方 90x100 | - | - | - | 悪化 |
| AI 自己修正（完成品を 10x で再投入） | 100 | 100x100 | 22 | 0.08% | 見た目は同等だが 65% の pixel が変わる。pixel-level 編集にならない |
| OSS `unfake` を flash / pro 出力に適用 | 整数 scale 10 / 13 | 101x101 / 78x78 | 21 / 20 | 2.8% / 2.2% | 非整数ピッチに位相が合わず縁がずれる。検査 FAIL |

表情差分（flash 100x100）: 生の漂流 25〜34% → 目・眉・口矩形の合成後 4〜8%。
G2 green16 preset: flash / pro とも検査 OK（階調 11〜12、コントラスト p95-p5 109.8）。
seed: `generationConfig.seed` で近い構図を再現（同 seed 2 回の平均 RGB 差 5.6/255）。完全一致ではない。

機械検査は全方式が通るため、**機械検査は美術品質の優劣を示さない**。採否は原寸 / 整数倍の目視と Owner 受入による。

## 専用サービス（机上）

| | PixelLab | Retro Diffusion |
| --- | --- | --- |
| ネイティブ解像度出力 | あり（`image_size` がそのまま論理サイズ） | あり（`upscale_output_factor` 既定 1） |
| 参照イラスト→ドット絵 | `image-to-pixelart`（出力 16〜512、`fixer` 忠実モード、パレット指定なし）、`-pro-flash`（ピッチ自動検出、`target_palette` beta） | `rd_pro__pixelate`（16〜256）、img2img、`rd_pro__edit` |
| 表情差分 | 専用 API 無し（`create-character-state`、`edit-image`） | 専用機能無し（`rd_pro__edit`、`image_edit`） |
| パレット | `TargetPalette` 2〜256 色 hex（1-bit / Game Boy 例示）→ G2 16 階調を渡せる見込み（未検証） | `input_palette` 画像、`palette_converter` 後処理。創業者「strict color limits は後処理が必要」 |
| seed | あり、「very similar」（完全一致非保証） | あり、「similar output」 |
| 料金 | 64x64 変換 $0.006、pixflux 64x64 $0.008、character-v3 $0.041。100 回でも $1〜5 | RD Fast $0.03、RD Pro（pixelate / edit）$0.18。1 キャラ + 差分 2 種 ≈ $3 |
| 規約 | 商用可、入力・出力を学習に使わない、debug 目的で入力画像を保存することあり、準拠法スウェーデン | 商用可、入力は学習に使わないが **出力はベンダー学習に使われ得る**、**無料枠の出力は公開扱い**、米国処理 |
| headless | REST（Bearer）+ Python SDK + MCP。curl で完結 | REST（`X-RD-Token`）+ MCP。Aseprite 拡張は別 model で Linux 保証なし |
| 独立実例 | itch.io devlog: 「生成物は必ず手直しパス」「41 色に palette-lock して手で cleanup」 | itch.io コメント: 「portrait は全身になりがち」「16〜32px は試行回数が要る」「cleanup filter は手作業と違う」 |
| 試す最小判断 | アカウント + `PIXELLAB_API_KEY`（無料枠で無印変換は試せる見込み） | アカウント + `RD_API_KEY`、無料 50 credits（出力公開を許容するか） |

## ローカル model（机上）

- 真の論理格子をネイティブ出力する open model は無い。全候補が 512〜1024px のドット風 + 整数倍縮小（svntax の FLUX.2 klein LoRA は 4 倍固定で最も素直、Apache-2.0、画像参照対応）
- CPU 2 core では SD1.5 5〜12 分 / SDXL + pixel-art-xl 10〜20 分 / FLUX.1-schnell 20〜30 分（公開ベンチからの外挿）。共有 pod では未試行
- 有望: FLUX.2 klein-4B + pixel LoRA、SDXL(Illustrious) + pixel-art-xl の i2i（第三者実証あり）。GPU 機か従量実行の承認が前提

## 結論（万能最良ではない）

- **Kohako の G2 用途（顔グラ・差分・green16）の推奨**: 現行 skill（Gemini + snap + cleanup + 合成 + preset）。
  model は **gemini-3.1-flash-image を第一候補**（格子が最も均一、pro-image の半額、候補 3 枚で 2 枚採用）、pro-image を次点。
  理由: 承認済み経路で完結、差分合成と G2 preset が script 化済み、実測で機械検査 + 目視を通る。seed で構図再現可
- **汎用カラーの推奨**: 同じ。canvas 80〜100 が実用域。80 未満は切り出し前提
- **次点（未試行の有望候補）**: PixelLab `image-to-pixelart`（安価、ネイティブ出力、パレット beta）。表情差分は専用機能が無く本 skill の合成 script を流用する前提。採用判断には Owner の account 作成と同一 brief での実測が必要
- **未検証の有望候補と限界**: Retro Diffusion RD Pro（高品質とされるが出力がベンダー学習に使われ得る・無料枠は公開）、FLUX.2 klein + pixel LoRA（GPU 要）
- **乗り換え条件**: 専用サービスが同一 brief で「初回採用率」「表情差分の漂流」「G2 preset 後の可読性」で現行を上回り、規約（入力画像の保持・学習）を Owner が許容する場合
