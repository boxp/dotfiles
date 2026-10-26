#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["pillow>=10", "numpy>=1.26"]
# ///
"""テスト用 fixture を生成する。正例と違反例の両方を作る。

  uv run make_fixtures.py <out-dir>
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
from pixelart_common import edge_mask  # noqa: E402

OUT = Path(sys.argv[1])
OUT.mkdir(parents=True, exist_ok=True)

rng = np.random.default_rng(317)

PALETTE = [(40, 40, 60), (90, 90, 140), (200, 180, 160), (240, 220, 200), (60, 140, 90), (220, 80, 80), (255, 240, 120), (20, 20, 30)]


def save(arr: np.ndarray, name: str) -> None:
    Image.fromarray(arr.astype(np.uint8), "RGBA").save(OUT / name)


def good_art(size: int = 24) -> np.ndarray:
    """clean な pixel cluster で描いた 24x24 の顔っぽい図形。alpha は 0/255。"""
    arr = np.zeros((size, size, 4), dtype=np.uint8)
    yy, xx = np.mgrid[0:size, 0:size]
    face = (xx - 12) ** 2 + (yy - 13) ** 2 <= 8**2
    hair = ((xx - 12) ** 2 + (yy - 10) ** 2 <= 9**2) & (yy < 11)
    arr[face] = (*PALETTE[2], 255)
    arr[hair] = (*PALETTE[0], 255)
    arr[12:14, 8:10] = (*PALETTE[7], 255)   # 左目 2x2
    arr[12:14, 14:16] = (*PALETTE[7], 255)  # 右目 2x2
    arr[16, 11:14] = (*PALETTE[5], 255)     # 口 3px
    arr[12, 9] = (*PALETTE[6], 255)         # 目のハイライト (意図した孤立 pixel)
    arr[12, 15] = (*PALETTE[6], 255)
    # 輪郭 1px
    edge = edge_mask(arr[..., 3] > 0)
    arr[edge] = (*PALETTE[7], 255)
    return arr


good = good_art()
save(good, "good_24.png")

# 部分透過 (halo) 違反
bad_alpha = good.copy()
bad_alpha[5, 5, 3] = 128
bad_alpha[6, 6, 3] = 40
save(bad_alpha, "bad_partial_alpha.png")

# 色数超過: ランダム色でノイズ
bad_colors = good.copy()
mask = bad_colors[..., 3] > 0
ys, xs = np.nonzero(mask)
pick = rng.choice(len(ys), 40, replace=False)
bad_colors[ys[pick], xs[pick], :3] = rng.integers(0, 255, (40, 3))
save(bad_colors, "bad_many_colors_isolated.png")

# 緑 fringe 違反: 縁を緑がかった色にする
bad_fringe = good.copy()
edge = edge_mask(bad_fringe[..., 3] > 0)
bad_fringe[edge, :3] = (40, 220, 60)
save(bad_fringe, "bad_green_fringe.png")

# 整数倍 nearest 拡大 (正例) と、1 ブロック壊した違反例
up = np.repeat(np.repeat(good, 4, axis=0), 4, axis=1)
save(up, "good_scaled_4x.png")
bad_up = up.copy()
bad_up[41, 41, :3] = (1, 2, 3)
save(bad_up, "bad_scaled_4x.png")

# AI 生成風の入力: 24x24 を 13.3 倍にし位相ずれ + ぼかし + ノイズ
scale = 13.3
big_w = int(round(24 * scale)) + 9
big = Image.fromarray(good, "RGBA").resize((int(round(24 * scale)), int(round(24 * scale))), Image.NEAREST)
canvas = Image.new("RGBA", (big_w, big_w), (0, 255, 0, 255))
canvas.paste(big, (5, 4), big)
canvas = canvas.filter(ImageFilter.GaussianBlur(1.2))
noise = rng.normal(0, 4, (big_w, big_w, 3))
arr = np.array(canvas).astype(np.float32)
arr[..., :3] = np.clip(arr[..., :3] + noise, 0, 255)
arr[..., 3] = 255
save(arr, "ai_like_24.png")

# snap 期待値: 緑背景を透過した good
expected = good.copy()
save(expected, "ai_like_24_expected.png")

# cleanup 入力: fringe + 飛び地 + 孤立ノイズ入り (キー色背景は不透明緑)
dirty = good.copy()
dirty[edge, :3] = (40, 220, 60)
dirty[1, 1] = (*PALETTE[5], 255)  # 1px の飛び地
dirty[20, 5, :3] = (123, 45, 67)  # 孤立ノイズ
dirty[~(dirty[..., 3] > 0)] = (0, 255, 0, 255)
save(dirty, "dirty_24.png")

# 輪郭に食い込む混色: 輪郭上の pixel を緑との混色 (キー色から距離 <= 100) にし、背景は不透明緑
bite = good.copy()
bite[~(bite[..., 3] > 0)] = (0, 255, 0, 255)
outline = edge_mask(good[..., 3] > 0)
bite_pts = []
for row in (5, 13, 20):
    cols = np.nonzero(outline[row])[0]
    bite_pts.append((row, int(cols[0])))
    if row == 13:
        bite_pts.append((row, int(cols[-1])))
for y, x in bite_pts:
    bite[y, x, :3] = (40, 200, 60)  # 緑寄りの混色 (距離 ~80)
save(bite, "bite_24.png")
import json
(OUT / "bite_24_points.json").write_text(json.dumps(bite_pts))

# G2 preset 正例 / 違反例
g2_good = np.zeros((40, 30, 4), dtype=np.uint8)
g2_good[5:35, 5:25] = (0, 17 * 8, 0, 255)
g2_good[10:15, 10:20] = (0, 17 * 15, 0, 255)
g2_good[20:25, 10:20] = (0, 17 * 2, 0, 255)
save(g2_good, "g2_good.png")
g2_bad = g2_good.copy()
g2_bad[12, 12, :3] = (0, 100, 0)  # 階調外
g2_bad[30, 10, :3] = (0, 0, 0)    # 不透明なのに level 0
save(g2_bad, "g2_bad.png")
g2_big = np.zeros((150, 300, 4), dtype=np.uint8)
g2_big[..., :3] = (0, 17 * 5, 0)
g2_big[..., 3] = 255
save(g2_big, "g2_too_big.png")

# 表情差分: 口だけ変えた (正例) / 全体を変えた (漂流)
variant = good.copy()
variant[16, 11:14] = (*PALETTE[2], 255)
variant[15:17, 10:15] = (*PALETTE[5], 255)
save(variant, "variant_mouth.png")
drift = np.roll(good, 3, axis=1)
save(drift, "variant_drift.png")

# カラー preset 変換元: 多色のグラデーション
grad = np.zeros((16, 32, 4), dtype=np.uint8)
grad[..., 0] = np.linspace(0, 255, 32)[None, :]
grad[..., 1] = np.linspace(255, 0, 16)[:, None]
grad[..., 2] = 128
grad[..., 3] = 255
grad[0:2, :, 3] = 0
save(grad, "gradient_16x32.png")
print(f"fixtures written to {OUT}")
