#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["pillow>=10", "numpy>=1.26"]
# ///
"""AI 生成の「ドット絵風」画像を論理 pixel grid に snap して原寸 (1 ドット = 1 px) にする。

AI 生成画像のドット格子はピッチも位相もゆらぐ。目標の論理グリッド (W x H) から
名目ピッチを求め、ピッチ比と位相を探索して「cell 内の色が最も均一になる格子」を選び、
各 cell の内側領域の最頻色 (mode) を 1 ドットにする。

使い方:
  uv run pixel_snap.py in.png -o out.png --grid 64x64
  uv run pixel_snap.py in.png -o out.png --pitch 16 --method median --report snap.json
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pixelart_common import die, load_rgba, parse_size, save_rgba, write_json  # noqa: E402


def axis_score(img: np.ndarray, axis: int, pitch: float, phase: float, inner: float) -> float:
    """axis (0=y, 1=x) 方向の格子に対する cell 内分散の平均。小さいほど格子が合っている。"""
    length = img.shape[axis]
    n = int((length - phase) // pitch)
    if n < 2:
        return float("inf")
    centers = phase + (np.arange(n) + 0.5) * pitch
    offsets = np.array([-inner / 2, 0.0, inner / 2]) * pitch
    coords = np.clip(np.round(centers[:, None] + offsets[None, :]).astype(int), 0, length - 1)
    if axis == 1:
        samples = img[:, coords, :3].astype(np.float32)  # (H, n, 3, C)
    else:
        samples = img[coords, :, :3].astype(np.float32)  # (n, 3, W, C)
        samples = np.moveaxis(samples, 2, 0)  # (W, n, 3, C)
    var = samples.var(axis=2).mean()
    return float(var)


def search_axis(img: np.ndarray, axis: int, nominal: float, inner: float, search: float) -> tuple[float, float, float]:
    best = (float("inf"), nominal, 0.0)
    ratios = np.linspace(1.0 - search, 1.0 + search, 33) if search > 0 else np.array([1.0])
    for ratio in ratios:
        pitch = nominal * ratio
        for phase in np.linspace(0.0, pitch, 16, endpoint=False):
            score = axis_score(img, axis, pitch, phase, inner)
            if score < best[0]:
                best = (score, float(pitch), float(phase))
    # 位相を細かく詰める
    score, pitch, phase = best
    for fine in np.linspace(phase - pitch / 16, phase + pitch / 16, 17):
        if fine < 0:
            continue
        s = axis_score(img, axis, pitch, fine, inner)
        if s < score:
            score, phase = s, float(fine)
    return score, pitch, phase


def gradient_profile(img: np.ndarray, axis: int) -> np.ndarray:
    """axis 方向の色変化量を 1 次元プロファイルにする (境界位置で大きくなる)。"""
    rgb = img[..., :3].astype(np.float32)
    if axis == 1:
        g = np.abs(np.diff(rgb, axis=1)).sum(axis=2).mean(axis=0)  # 長さ W-1、g[x] は x と x+1 の境界
    else:
        g = np.abs(np.diff(rgb, axis=0)).sum(axis=2).mean(axis=1)
    return g


def detect_pitch(img: np.ndarray, axis: int, lo: float, hi: float, tolerance: float = 0.9) -> tuple[float, float, float]:
    """境界の周期性からドット幅 (整数 lag) を推定する。

    色変化量プロファイルの自己相関を取り、[lo, hi] 内の極大のうち最大値の tolerance 倍以上を
    持つ最小の lag を採用する (真のピッチの整数倍も極大になるため、最小側を選ぶ)。
    戻り値: (autocorrelation, lag, 0.0)。サブピクセルのピッチと位相は search_axis で詰める。
    """
    g = gradient_profile(img, axis)
    g = g - g.mean()
    ac = np.correlate(g, g, mode="full")[g.shape[0] - 1 :]
    if ac[0] <= 0:
        return (0.0, lo, 0.0)
    ac = ac / ac[0]
    lo_i, hi_i = max(2, int(np.floor(lo))), min(int(np.ceil(hi)), ac.shape[0] - 2)
    peaks = [(float(ac[lag]), float(lag)) for lag in range(lo_i, hi_i + 1) if ac[lag] > ac[lag - 1] and ac[lag] >= ac[lag + 1]]
    if not peaks:
        return (0.0, lo, 0.0)
    top = max(v for v, _ in peaks)
    for value, lag in peaks:  # 小さい lag から順
        if value >= top * tolerance:
            return (value, lag, 0.0)
    return (top, max(peaks)[1], 0.0)


def cell_color(region: np.ndarray, method: str) -> np.ndarray:
    """region: (k, 4) uint8。cell を代表する RGBA を返す。"""
    if region.shape[0] == 0:
        return np.zeros(4, dtype=np.uint8)
    alpha = np.uint8(255 if np.median(region[:, 3]) >= 128 else 0)
    rgb = region[:, :3]
    if method == "center":
        out = rgb[region.shape[0] // 2]
    elif method == "median":
        out = np.median(rgb, axis=0)
    else:  # mode: 4bit/ch で bucket 化して最頻 bucket の平均色
        keys = (rgb[:, 0] >> 4).astype(np.int32) * 256 + (rgb[:, 1] >> 4).astype(np.int32) * 16 + (rgb[:, 2] >> 4)
        values, counts = np.unique(keys, return_counts=True)
        winner = values[np.argmax(counts)]
        out = rgb[keys == winner].astype(np.float32).mean(axis=0)
    return np.array([*np.round(out).astype(np.uint8), alpha], dtype=np.uint8)


def snap(img: np.ndarray, pitch_x: float, pitch_y: float, phase_x: float, phase_y: float,
         cols: int, rows: int, inner: float, method: str) -> np.ndarray:
    h, w = img.shape[:2]
    out = np.zeros((rows, cols, 4), dtype=np.uint8)
    for j in range(rows):
        cy = phase_y + (j + 0.5) * pitch_y
        y0 = int(np.clip(np.floor(cy - inner / 2 * pitch_y), 0, h - 1))
        y1 = int(np.clip(np.ceil(cy + inner / 2 * pitch_y), y0 + 1, h))
        for i in range(cols):
            cx = phase_x + (i + 0.5) * pitch_x
            x0 = int(np.clip(np.floor(cx - inner / 2 * pitch_x), 0, w - 1))
            x1 = int(np.clip(np.ceil(cx + inner / 2 * pitch_x), x0 + 1, w))
            out[j, i] = cell_color(img[y0:y1, x0:x1].reshape(-1, 4), method)
    return out


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("input")
    ap.add_argument("-o", "--output", required=True)
    group = ap.add_mutually_exclusive_group(required=True)
    group.add_argument("--grid", help="論理グリッド WxH (例: 64x64)。'auto' で境界周期からドット幅を推定")
    group.add_argument("--pitch", type=float, help="入力画像の 1 ドット幅 (px)。grid は画像寸法から算出")
    group.add_argument("--like", help="基準画像の --report JSON と同じ pitch/phase/grid を使う (表情差分用。探索しない)")
    ap.add_argument("--pitch-range", default="4,40", help="--grid auto の探索範囲 (px)")
    ap.add_argument("--method", choices=["mode", "median", "center"], default="mode")
    ap.add_argument("--inner", type=float, default=0.5, help="cell 内で色を取る領域の割合 (0-1)")
    ap.add_argument("--search", type=float, default=0.06, help="ピッチ探索幅 (±比率)。0 で名目ピッチ固定")
    ap.add_argument("--no-phase-search", action="store_true", help="位相探索を行わず 0 とする")
    ap.add_argument("--report", help="推定結果を JSON で書き出す")
    args = ap.parse_args()

    img = load_rgba(args.input)
    h, w = img.shape[:2]
    detected = None
    if args.like:
        import json

        like = json.loads(Path(args.like).read_text())
        if like["input_size"] != [w, h]:
            die(f"--like の入力寸法 {like['input_size']} と異なる ({w}x{h})")
        cols, rows = like["grid"]
        px, py = like["pitch"]
        phx, phy = like["phase"]
        nominal_x, nominal_y = px, py
        out = snap(img, px, py, phx, phy, cols, rows, args.inner, args.method)
        save_rgba(out, args.output)
        write_json({**like, "input": args.input, "output": args.output, "like": args.like}, args.report)
        print(f"snapped {w}x{h} -> {cols}x{rows} like {args.like} -> {args.output}")
        return
    if args.grid == "auto":
        lo, hi = (float(v) for v in args.pitch_range.split(","))
        dx = detect_pitch(img, 1, lo, hi)
        dy = detect_pitch(img, 0, lo, hi)
        detected = {"x": dx, "y": dy}
        if dx[0] <= 0 or dy[0] <= 0:
            die("ドット格子の周期を検出できない (境界が少ない疎な絵でも起きる)。--grid WxH か --pitch を明示して再実行する")
        # 整数 lag の周りでサブピクセルのピッチを詰め、格子数を決める
        sx0, px0, _ = search_axis(img, 1, dx[1], args.inner, 0.1)
        sy0, py0, _ = search_axis(img, 0, dy[1], args.inner, 0.1)
        nominal_x, nominal_y = px0, py0
        cols, rows = int(round(w / nominal_x)), int(round(h / nominal_y))
    elif args.grid:
        cols, rows = parse_size(args.grid)
        nominal_x, nominal_y = w / cols, h / rows
    else:
        nominal_x = nominal_y = args.pitch
        cols, rows = int(round(w / nominal_x)), int(round(h / nominal_y))
    if cols < 1 or rows < 1:
        die("グリッドが小さすぎる")

    if args.no_phase_search:
        sx, px, phx = axis_score(img, 1, nominal_x, 0.0, args.inner), nominal_x, 0.0
        sy, py, phy = axis_score(img, 0, nominal_y, 0.0, args.inner), nominal_y, 0.0
    else:
        sx, px, phx = search_axis(img, 1, nominal_x, args.inner, args.search)
        sy, py, phy = search_axis(img, 0, nominal_y, args.inner, args.search)
        # 探索後も論理グリッド数は維持する（端の cell は画像外にはみ出しても clamp される）
    out = snap(img, px, py, phx, phy, cols, rows, args.inner, args.method)
    save_rgba(out, args.output)

    baseline_x = axis_score(img, 1, nominal_x, 0.0, args.inner)
    baseline_y = axis_score(img, 0, nominal_y, 0.0, args.inner)
    report = {
        "input": args.input,
        "output": args.output,
        "input_size": [w, h],
        "grid": [cols, rows],
        "nominal_pitch": [round(nominal_x, 4), round(nominal_y, 4)],
        "pitch": [round(px, 4), round(py, 4)],
        "phase": [round(phx, 3), round(phy, 3)],
        "cell_variance": [round(sx, 2), round(sy, 2)],
        "cell_variance_nominal": [round(baseline_x, 2), round(baseline_y, 2)],
        "method": args.method,
        "inner": args.inner,
    }
    if detected:
        report["detected"] = {k: {"autocorrelation": round(v[0], 3), "lag": v[1]} for k, v in detected.items()}
    write_json(report, args.report)
    print(f"snapped {w}x{h} -> {cols}x{rows} (pitch {px:.3f}x{py:.3f}, phase {phx:.2f},{phy:.2f}) -> {args.output}")


if __name__ == "__main__":
    main()
