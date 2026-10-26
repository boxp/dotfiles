#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["pillow>=10", "numpy>=1.26"]
# ///
"""原寸ドット絵の透過と孤立 pixel を整理する。

順に適用する (指定したものだけ):
  1. --key        : キー色 (例 #00FF00) に近い pixel を透過にする
  2. alpha を 0/255 に二値化 (常に。--alpha-threshold)
  3. --min-island : 指定 px 未満の不透明な飛び地 (4 連結) を透過にする
  4. --defringe   : 透過に接する不透明 pixel のうちキー色に寄った色を、周囲の不透明色で置き換える
  5. --despeckle  : 8 近傍に同色が無い孤立 pixel を周囲の最頻色で置き換える
                    (--protect-bright で周囲より明るいハイライト点を保護、--protect で色指定保護)
  6. --trim / --canvas / --anchor : 内容を bbox で切り出し、指定 canvas に配置

使い方:
  uv run pixel_cleanup.py in.png -o out.png --key '#00FF00' --key-tol 90 --defringe 120 --min-island 3 \
      --despeckle --protect-bright --canvas 64x64 --anchor top
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pixelart_common import (  # noqa: E402
    color_distance,
    connected_components,
    die,
    edge_mask,
    isolated_mask,
    load_rgba,
    luminance,
    opaque_mask,
    parse_hex,
    parse_size,
    save_rgba,
)


def neighbor_mode(arr: np.ndarray, mask: np.ndarray, y: int, x: int, exclude: np.ndarray | None = None) -> np.ndarray | None:
    h, w = mask.shape
    colors = []
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            if dy == 0 and dx == 0:
                continue
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and (exclude is None or not exclude[ny, nx]):
                colors.append(tuple(int(v) for v in arr[ny, nx, :3]))
    if not colors:
        return None
    values, counts = np.unique(np.array(colors), axis=0, return_counts=True)
    return values[np.argmax(counts)]


def remove_islands(arr: np.ndarray, min_island: int) -> tuple[np.ndarray, int]:
    mask = opaque_mask(arr)
    labels, n = connected_components(mask)
    removed = 0
    for label in range(1, n + 1):
        comp = labels == label
        size = int(comp.sum())
        if size < min_island:
            arr[comp] = 0
            removed += 1
    return arr, removed


def defringe(arr: np.ndarray, key: tuple[int, int, int], tol: float, passes: int = 2) -> tuple[np.ndarray, int]:
    replaced = 0
    for _ in range(passes):
        mask = opaque_mask(arr)
        edge = edge_mask(mask)
        fringe = edge & (color_distance(arr, key) <= tol)
        if not fringe.any():
            break
        ys, xs = np.nonzero(fringe)
        new = arr.copy()
        for y, x in zip(ys, xs):
            color = neighbor_mode(arr, mask, y, x, exclude=fringe)
            if color is None:
                new[y, x] = 0  # 置き換え元が無ければ透過にする
            else:
                new[y, x, :3] = color
            replaced += 1
        arr = new
    return arr, replaced


def despeckle(arr: np.ndarray, protect_bright: bool, protect_colors: list[tuple[int, int, int]],
              bright_margin: float, passes: int) -> tuple[np.ndarray, int, int]:
    replaced = 0
    protected = 0
    for _ in range(passes):
        mask = opaque_mask(arr)
        iso = isolated_mask(arr, mask)
        if not iso.any():
            break
        lum = luminance(arr[..., :3])
        new = arr.copy()
        ys, xs = np.nonzero(iso)
        changed = 0
        for y, x in zip(ys, xs):
            color = tuple(int(v) for v in arr[y, x, :3])
            if color in protect_colors:
                protected += 1
                continue
            if protect_bright:
                h, w = mask.shape
                neigh = [
                    lum[ny, nx]
                    for ny in range(max(0, y - 1), min(h, y + 2))
                    for nx in range(max(0, x - 1), min(w, x + 2))
                    if (ny, nx) != (y, x) and mask[ny, nx]
                ]
                if neigh and lum[y, x] >= max(neigh) + bright_margin:
                    protected += 1
                    continue
            mode = neighbor_mode(arr, mask, y, x)
            if mode is None:
                continue
            new[y, x, :3] = mode
            changed += 1
        arr = new
        replaced += changed
        if changed == 0:
            break
    return arr, replaced, protected


def place(arr: np.ndarray, canvas: tuple[int, int] | None, anchor: str, trim: bool) -> np.ndarray:
    mask = opaque_mask(arr)
    if trim or canvas:
        if mask.any():
            ys, xs = np.nonzero(mask)
            arr = arr[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1]
    if not canvas:
        return arr
    cw, ch = canvas
    h, w = arr.shape[:2]
    if w > cw or h > ch:
        die(f"内容 {w}x{h} が canvas {cw}x{ch} より大きい。縮小はせず、生成側のグリッドを見直す")
    out = np.zeros((ch, cw, 4), dtype=np.uint8)
    x0 = (cw - w) // 2
    y0 = {"top": 0, "center": (ch - h) // 2, "bottom": ch - h}[anchor]
    out[y0 : y0 + h, x0 : x0 + w] = arr
    return out


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("input")
    ap.add_argument("-o", "--output", required=True)
    ap.add_argument("--key", help="透過にするキー色 (#rrggbb)")
    ap.add_argument("--key-tol", type=float, default=90.0, help="キー色との RGB 距離の許容値")
    ap.add_argument("--alpha-threshold", type=int, default=128)
    ap.add_argument("--min-island", type=int, default=0, help="この px 未満の飛び地を消す")
    ap.add_argument("--defringe", type=float, default=0.0, help="縁 fringe とみなすキー色距離 (0 で無効、--key 必須)")
    ap.add_argument("--despeckle", action="store_true")
    ap.add_argument("--despeckle-passes", type=int, default=1)
    ap.add_argument("--protect-bright", action="store_true", help="周囲より明るい孤立点 (ハイライト) を残す")
    ap.add_argument("--bright-margin", type=float, default=40.0)
    ap.add_argument("--protect", action="append", default=[], help="保護する色 (#rrggbb、複数可)")
    ap.add_argument("--trim", action="store_true")
    ap.add_argument("--canvas", help="配置先 canvas WxH")
    ap.add_argument("--anchor", choices=["top", "center", "bottom"], default="top")
    args = ap.parse_args()

    arr = load_rgba(args.input)
    log: list[str] = []
    key = parse_hex(args.key) if args.key else None
    if key:
        keyed = color_distance(arr, key) <= args.key_tol
        arr[keyed] = 0
        log.append(f"key {args.key}: {int(keyed.sum())} px -> transparent")
    alpha = arr[..., 3] >= args.alpha_threshold
    partial = int(((arr[..., 3] > 0) & (arr[..., 3] < 255)).sum())
    arr[..., 3] = np.where(alpha, 255, 0).astype(np.uint8)
    arr[~alpha, :3] = 0
    log.append(f"alpha binarized (partial before: {partial})")
    if args.min_island > 0:
        arr, removed = remove_islands(arr, args.min_island)
        log.append(f"islands < {args.min_island}px removed: {removed}")
    if args.defringe > 0:
        if not key:
            die("--defringe には --key が必要")
        arr, replaced = defringe(arr, key, args.defringe)
        log.append(f"fringe replaced: {replaced}")
    if args.despeckle:
        protect_colors = [parse_hex(c) for c in args.protect]
        arr, replaced, protected = despeckle(arr, args.protect_bright, protect_colors, args.bright_margin, args.despeckle_passes)
        log.append(f"isolated replaced: {replaced}, protected: {protected}")
    canvas = parse_size(args.canvas) if args.canvas else None
    arr = place(arr, canvas, args.anchor, args.trim)
    save_rgba(arr, args.output)
    print("cleanup: " + "; ".join(log) + f" -> {args.output} ({arr.shape[1]}x{arr.shape[0]})")


if __name__ == "__main__":
    main()
