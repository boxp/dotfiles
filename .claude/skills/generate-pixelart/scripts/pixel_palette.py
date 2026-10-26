#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["pillow>=10", "numpy>=1.26"]
# ///
"""原寸ドット絵の色をパレットに揃える。

- `--colors N`      : 不透明 pixel を median cut で N 色に量子化 (dither 無し)
- `--palette SPEC`  : 固定パレット (`#aabbcc,#ddeeff` または 1 行 1 色のファイル) の最近傍色へ写像
- `--preset NAME`   : preset へ変換。`g2-green16` は輝度を 16 階調 green に写像し、
                      不透明 pixel は level >= --floor (既定 1) に保つ (level 0 = 黒 = G2 の透過)

使い方:
  uv run pixel_palette.py in.png -o out.png --colors 24
  uv run pixel_palette.py in.png -o out.png --preset g2-green16 --stretch 2,98 --gamma 0.9
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pixelart_common import PRESETS, die, load_rgba, luminance, opaque_mask, parse_palette, save_rgba  # noqa: E402


def quantize_colors(arr: np.ndarray, colors: int) -> np.ndarray:
    mask = opaque_mask(arr)
    rgb = Image.fromarray(arr[..., :3], "RGB")
    # 透過部の色が palette を食わないよう、透過部は不透明部の平均色で埋めてから量子化する
    if mask.any() and not mask.all():
        fill = arr[..., :3][mask].mean(axis=0).astype(np.uint8)
        tmp = arr[..., :3].copy()
        tmp[~mask] = fill
        rgb = Image.fromarray(tmp, "RGB")
    q = rgb.quantize(colors=colors, method=Image.Quantize.MEDIANCUT, kmeans=3, dither=Image.Dither.NONE)
    out = np.array(q.convert("RGBA"), dtype=np.uint8)
    out[..., 3] = arr[..., 3]
    out[~mask, :3] = 0
    return out


def map_palette(arr: np.ndarray, palette: list[tuple[int, int, int]]) -> np.ndarray:
    pal = np.array(palette, dtype=np.int32)
    rgb = arr[..., :3].astype(np.int32)
    dist = ((rgb[..., None, :] - pal[None, None, :, :]) ** 2).sum(axis=-1)
    idx = dist.argmin(axis=-1)
    out = arr.copy()
    out[..., :3] = pal[idx].astype(np.uint8)
    mask = opaque_mask(arr)
    out[~mask, :3] = 0
    return out


def to_preset(arr: np.ndarray, name: str, stretch: tuple[float, float] | None, gamma: float, floor: int,
              invert: bool) -> tuple[np.ndarray, dict]:
    preset = PRESETS[name]
    palette = preset["palette"]
    levels = len(palette)
    mask = opaque_mask(arr)
    lum = luminance(arr[..., :3])
    info: dict = {"preset": name}
    if mask.any():
        lo, hi = (np.percentile(lum[mask], stretch) if stretch else (lum[mask].min(), lum[mask].max()))
        if hi - lo < 1e-6:
            hi = lo + 1.0
        info["stretch_range"] = [float(lo), float(hi)]
    else:
        lo, hi = 0.0, 255.0
    norm = np.clip((lum - lo) / (hi - lo), 0.0, 1.0)
    if invert:
        norm = 1.0 - norm
    norm = norm ** gamma
    level = np.round(norm * (levels - 1)).astype(np.int32)
    level = np.clip(level, 0, levels - 1)
    if floor > 0:
        level[mask] = np.maximum(level[mask], floor)
    out = np.zeros_like(arr)
    pal = np.array(palette, dtype=np.uint8)
    out[..., :3] = pal[level]
    out[..., 3] = np.where(mask, 255, 0).astype(np.uint8)
    out[~mask, :3] = 0
    info["levels_used"] = sorted(int(v) for v in np.unique(level[mask])) if mask.any() else []
    return out, info


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("input")
    ap.add_argument("-o", "--output", required=True)
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--colors", type=int)
    g.add_argument("--palette")
    g.add_argument("--preset", choices=sorted(PRESETS))
    ap.add_argument("--stretch", default="1,99", help="preset 用: 輝度の percentile 範囲 (例 1,99)。'none' で無効")
    ap.add_argument("--gamma", type=float, default=1.0, help="preset 用: 階調の gamma")
    ap.add_argument("--floor", type=int, default=1, help="preset 用: 不透明 pixel の最低 level")
    ap.add_argument("--invert", action="store_true", help="preset 用: 明暗を反転")
    args = ap.parse_args()

    arr = load_rgba(args.input)
    if args.colors:
        if not 1 <= args.colors <= 256:
            die("--colors は 1-256")
        out = quantize_colors(arr, args.colors)
        note = f"{args.colors} colors (median cut)"
    elif args.palette:
        out = map_palette(arr, parse_palette(args.palette))
        note = "fixed palette"
    else:
        stretch = None if args.stretch.lower() == "none" else tuple(float(v) for v in args.stretch.split(","))
        out, info = to_preset(arr, args.preset, stretch, args.gamma, args.floor, args.invert)
        note = f"preset {args.preset} levels_used={info['levels_used']}"
    save_rgba(out, args.output)
    print(f"palette: {note} -> {args.output}")


if __name__ == "__main__":
    main()
