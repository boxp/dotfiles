#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["pillow>=10", "numpy>=1.26"]
# ///
"""表情差分の合成: 差分画像から指定領域だけを基準画像に貼り、それ以外を基準と完全一致させる。

AI に「表情だけ変えて」と頼んでも全体が描き直される (本票の計測で 17-28% の pixel が変化)。
目・口の矩形だけを採用して漂流を機械的に封じる。

  uv run pixel_composite.py base.png variant.png -o out.png --region 22,26,60,50 [--report out.json]

--region は x0,y0,x1,y1 (x1,y1 は含まない)。複数指定可。
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pixelart_common import die, load_rgba, opaque_mask, save_rgba, write_json  # noqa: E402


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("base")
    ap.add_argument("variant")
    ap.add_argument("-o", "--output", required=True)
    ap.add_argument("--region", action="append", required=True, help="x0,y0,x1,y1 (複数可)")
    ap.add_argument("--report")
    args = ap.parse_args()

    base = load_rgba(args.base)
    var = load_rgba(args.variant)
    if base.shape != var.shape:
        die(f"寸法が違う: base {base.shape[1]}x{base.shape[0]} / variant {var.shape[1]}x{var.shape[0]}")
    h, w = base.shape[:2]
    out = base.copy()
    regions = []
    for spec in args.region:
        x0, y0, x1, y1 = (int(v) for v in spec.split(","))
        if not (0 <= x0 < x1 <= w and 0 <= y0 < y1 <= h):
            die(f"region {spec} が画像 {w}x{h} の範囲外")
        out[y0:y1, x0:x1] = var[y0:y1, x0:x1]
        regions.append([x0, y0, x1, y1])
    changed = np.any(out != base, axis=-1)
    total = int(np.logical_or(opaque_mask(base), opaque_mask(out)).sum()) or 1
    save_rgba(out, args.output)
    report = {
        "base": args.base,
        "variant": args.variant,
        "output": args.output,
        "regions": regions,
        "changed_pixels": int(changed.sum()),
        "changed_ratio": round(float(changed.sum() / total), 4),
    }
    write_json(report, args.report)
    print(f"composite: {len(regions)} region(s), changed {report['changed_pixels']} px ({report['changed_ratio']:.2%}) -> {args.output}")


if __name__ == "__main__":
    main()
