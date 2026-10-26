#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["pillow>=10", "numpy>=1.26"]
# ///
"""ドット絵 PNG の機械検査。違反があれば exit 1、結果は JSON で出す。

検査項目 (指定したものだけ有効、既定は alpha 離散性のみ):
  --expect-size WxH   寸法一致
  --max-colors N      不透明 pixel の色数上限
  --alpha-levels L    許容する alpha 値 (既定 0,255)。部分透過 (halo) を検出
  --key C --fringe-tol T  透過に接する不透明 pixel がキー色から距離 T 以内なら fringe 違反
  --max-isolated R    8 近傍に同色が無い孤立 pixel の比率上限 (不透明 pixel に対する)
  --scale N           ファイルが論理 grid の N 倍 nearest 拡大であること (全 NxN ブロックが単色)
  --palette SPEC      不透明色がパレットの部分集合であること
  --preset NAME       preset 制約 (g2-green16: 色 ⊂ 16 階調 green、寸法 ≤ 288x144、不透明 level0 禁止)
  --compare BASE --max-drift R  同寸の基準画像との差分 pixel 比率上限 (表情差分の漂流検査)
  --min-contrast V    不透明 pixel 輝度の (p95 - p5) 下限 (単色 preset の読みやすさ)

使い方:
  uv run pixel_check.py out.png --expect-size 64x64 --max-colors 32 --max-isolated 0.02 --json report.json
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pixelart_common import (  # noqa: E402
    PRESETS,
    color_distance,
    die,
    edge_mask,
    isolated_mask,
    load_rgba,
    luminance,
    opaque_mask,
    parse_hex,
    parse_palette,
    parse_size,
    unique_colors,
    write_json,
)


def check_scale(arr: np.ndarray, scale: int) -> tuple[bool, dict]:
    h, w = arr.shape[:2]
    info: dict = {"scale": scale}
    if w % scale or h % scale:
        info["reason"] = f"{w}x{h} は {scale} の倍数でない"
        return False, info
    blocks = arr.reshape(h // scale, scale, w // scale, scale, 4).transpose(0, 2, 1, 3, 4)
    flat = blocks.reshape(h // scale, w // scale, scale * scale, 4)
    uniform = np.all(flat == flat[:, :, :1, :], axis=(2, 3))
    bad = int((~uniform).sum())
    info["logical_size"] = [w // scale, h // scale]
    info["non_uniform_blocks"] = bad
    return bad == 0, info


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("input")
    ap.add_argument("--expect-size")
    ap.add_argument("--max-colors", type=int)
    ap.add_argument("--alpha-levels", default="0,255")
    ap.add_argument("--key")
    ap.add_argument("--fringe-tol", type=float, default=90.0)
    ap.add_argument("--max-isolated", type=float)
    ap.add_argument("--scale", type=int)
    ap.add_argument("--palette")
    ap.add_argument("--preset", choices=sorted(PRESETS))
    ap.add_argument("--allow-opaque-transparent-level", action="store_true", help="preset の透過 level を不透明 pixel に許す")
    ap.add_argument("--compare")
    ap.add_argument("--max-drift", type=float, default=0.25)
    ap.add_argument("--min-contrast", type=float)
    ap.add_argument("--json", help="結果 JSON の出力先 (省略時は標準出力)")
    args = ap.parse_args()

    arr = load_rgba(args.input)
    h, w = arr.shape[:2]
    mask = opaque_mask(arr)
    colors = unique_colors(arr, mask)
    alpha_values = sorted(int(v) for v in np.unique(arr[..., 3]))
    opaque_count = int(mask.sum())
    failures: list[str] = []
    result: dict = {
        "input": args.input,
        "size": [w, h],
        "opaque_pixels": opaque_count,
        "colors": int(len(colors)),
        "alpha_values": alpha_values,
        "checks": {},
    }

    if args.expect_size:
        ew, eh = parse_size(args.expect_size)
        ok = (w, h) == (ew, eh)
        result["checks"]["size"] = {"ok": ok, "expected": [ew, eh]}
        if not ok:
            failures.append(f"size {w}x{h} != {ew}x{eh}")

    allowed_alpha = {int(v) for v in args.alpha_levels.split(",")}
    bad_alpha = [v for v in alpha_values if v not in allowed_alpha]
    partial = int(np.isin(arr[..., 3], list(allowed_alpha), invert=True).sum())
    result["checks"]["alpha_discrete"] = {"ok": not bad_alpha, "allowed": sorted(allowed_alpha), "violating_pixels": partial}
    if bad_alpha:
        failures.append(f"alpha に許容外の値 {bad_alpha[:5]} ({partial} px)")

    if args.max_colors is not None:
        ok = len(colors) <= args.max_colors
        result["checks"]["max_colors"] = {"ok": ok, "max": args.max_colors}
        if not ok:
            failures.append(f"colors {len(colors)} > {args.max_colors}")

    if args.key:
        key = parse_hex(args.key)
        edge = edge_mask(mask)
        fringe = edge & (color_distance(arr, key) <= args.fringe_tol)
        n = int(fringe.sum())
        keyed_inside = int((mask & (color_distance(arr, key) <= args.fringe_tol / 2)).sum())
        result["checks"]["fringe"] = {"ok": n == 0, "key": args.key, "edge_pixels": int(edge.sum()), "fringe_pixels": n,
                                      "key_colored_opaque_pixels": keyed_inside}
        if n:
            failures.append(f"fringe {n} px (キー色 {args.key} に近い縁)")

    iso = isolated_mask(arr, mask)
    iso_ratio = float(iso.sum() / opaque_count) if opaque_count else 0.0
    result["isolated_pixels"] = int(iso.sum())
    result["isolated_ratio"] = round(iso_ratio, 4)
    if args.max_isolated is not None:
        ok = iso_ratio <= args.max_isolated
        result["checks"]["isolated"] = {"ok": ok, "max_ratio": args.max_isolated}
        if not ok:
            failures.append(f"isolated ratio {iso_ratio:.4f} > {args.max_isolated}")

    if args.scale:
        ok, info = check_scale(arr, args.scale)
        info["ok"] = ok
        result["checks"]["scale"] = info
        if not ok:
            failures.append(f"scale {args.scale}: " + (info.get("reason") or f"non-uniform blocks {info['non_uniform_blocks']}"))

    palette = None
    if args.palette:
        palette = parse_palette(args.palette)
    if args.preset:
        preset = PRESETS[args.preset]
        palette = preset["palette"]
        mw, mh = preset["max_width"], preset["max_height"]
        ok = w <= mw and h <= mh
        result["checks"]["preset_size"] = {"ok": ok, "max": [mw, mh]}
        if not ok:
            failures.append(f"preset {args.preset}: {w}x{h} > {mw}x{mh}")
        if not args.allow_opaque_transparent_level:
            tcolor = np.array(palette[preset["transparent_level"]], dtype=np.uint8)
            n = int((mask & np.all(arr[..., :3] == tcolor, axis=-1)).sum())
            result["checks"]["preset_transparent_level"] = {"ok": n == 0, "opaque_pixels_at_transparent_level": n}
            if n:
                failures.append(f"preset {args.preset}: 不透明 pixel が透過 level の色 ({n} px)。G2 では消える")
    if palette is not None:
        pal = {tuple(int(v) for v in c) for c in palette}
        outside = [tuple(int(v) for v in c) for c in colors if tuple(int(v) for v in c) not in pal]
        result["checks"]["palette"] = {"ok": not outside, "palette_size": len(pal), "outside": [f"#{r:02x}{g:02x}{b:02x}" for r, g, b in outside[:16]],
                                       "outside_count": len(outside)}
        if outside:
            failures.append(f"palette 外の色 {len(outside)}")

    if args.min_contrast is not None:
        lum = luminance(arr[..., :3])[mask]
        spread = float(np.percentile(lum, 95) - np.percentile(lum, 5)) if lum.size else 0.0
        ok = spread >= args.min_contrast
        result["checks"]["contrast"] = {"ok": ok, "p95_minus_p5": round(spread, 1), "min": args.min_contrast}
        if not ok:
            failures.append(f"contrast {spread:.1f} < {args.min_contrast}")

    if args.compare:
        base = load_rgba(args.compare)
        if base.shape != arr.shape:
            result["checks"]["compare"] = {"ok": False, "reason": f"size differs {base.shape[1]}x{base.shape[0]}"}
            failures.append("compare: 寸法が違う")
        else:
            changed = np.any(base != arr, axis=-1)
            total = int(np.logical_or(opaque_mask(base), mask).sum()) or 1
            ratio = float(changed.sum() / total)
            info = {"ok": ratio <= args.max_drift, "changed_pixels": int(changed.sum()), "changed_ratio": round(ratio, 4),
                    "max_drift": args.max_drift}
            if changed.any():
                ys, xs = np.nonzero(changed)
                info["changed_bbox"] = [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())]
            base_colors = {tuple(int(v) for v in c) for c in unique_colors(base)}
            new_colors = {tuple(int(v) for v in c) for c in colors}
            info["new_colors_not_in_base"] = len(new_colors - base_colors)
            result["checks"]["compare"] = info
            if ratio > args.max_drift:
                failures.append(f"drift {ratio:.4f} > {args.max_drift}")

    result["ok"] = not failures
    result["failures"] = failures
    write_json(result, args.json)
    status = "OK" if not failures else "FAIL"
    print(f"{status}: {args.input} {w}x{h} colors={len(colors)} alpha={alpha_values} isolated={iso_ratio:.4f}"
          + ("" if not failures else " | " + "; ".join(failures)), file=sys.stderr)
    sys.exit(0 if not failures else 1)


if __name__ == "__main__":
    main()
