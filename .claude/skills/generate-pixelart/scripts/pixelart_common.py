"""generate-pixelart 支援 script 共通部。

各 script は PEP 723 inline metadata を持ち `uv run <script>` で実行する。
このモジュールは同じディレクトリから import される。
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

# Even G2 向け preset: 16 階調 green、level 0 (黒) は透過扱い。
G2_GREEN16 = [(0, level * 17, 0) for level in range(16)]

PRESETS = {
    "g2-green16": {
        "palette": G2_GREEN16,
        "max_width": 288,
        "max_height": 144,
        "transparent_level": 0,
    },
}


def load_rgba(path: str | Path) -> np.ndarray:
    """PNG 等を RGBA uint8 配列 (H, W, 4) として読む。"""
    with Image.open(path) as im:
        return np.array(im.convert("RGBA"), dtype=np.uint8)


def save_rgba(arr: np.ndarray, path: str | Path) -> None:
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(arr.astype(np.uint8), "RGBA").save(path)


def parse_hex(color: str) -> tuple[int, int, int]:
    color = color.strip().lstrip("#")
    if len(color) != 6:
        raise ValueError(f"色は #rrggbb 形式で指定する: {color!r}")
    return tuple(int(color[i : i + 2], 16) for i in (0, 2, 4))  # type: ignore[return-value]


def parse_palette(spec: str) -> list[tuple[int, int, int]]:
    """`#aabbcc,#ddeeff` の文字列、または 1 行 1 色のファイルパスをパレットに変換する。"""
    path = Path(spec)
    if path.exists():
        tokens = [t.strip() for t in path.read_text().replace(",", "\n").splitlines()]
    else:
        tokens = [t.strip() for t in spec.split(",")]
    colors = [parse_hex(t) for t in tokens if t and not t.startswith("//")]
    if not colors:
        raise ValueError("パレットが空")
    return colors


def parse_size(spec: str) -> tuple[int, int]:
    w, h = spec.lower().split("x")
    return int(w), int(h)


def opaque_mask(arr: np.ndarray, threshold: int = 128) -> np.ndarray:
    return arr[..., 3] >= threshold


def unique_colors(arr: np.ndarray, mask: np.ndarray | None = None) -> np.ndarray:
    """不透明 pixel の RGB ユニーク色 (N, 3)。"""
    if mask is None:
        mask = opaque_mask(arr)
    rgb = arr[..., :3][mask]
    if rgb.size == 0:
        return np.zeros((0, 3), dtype=np.uint8)
    return np.unique(rgb, axis=0)


def color_distance(a: np.ndarray, color: tuple[int, int, int]) -> np.ndarray:
    diff = a[..., :3].astype(np.int32) - np.array(color, dtype=np.int32)
    return np.sqrt((diff * diff).sum(axis=-1))


def luminance(rgb: np.ndarray) -> np.ndarray:
    rgb = rgb.astype(np.float32)
    return 0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2]


def isolated_mask(arr: np.ndarray, mask: np.ndarray | None = None) -> np.ndarray:
    """8 近傍に同色の不透明 pixel が 1 つも無い不透明 pixel を True にする。"""
    if mask is None:
        mask = opaque_mask(arr)
    h, w = mask.shape
    rgb = arr[..., :3].astype(np.int32)
    padded = np.pad(rgb, ((1, 1), (1, 1), (0, 0)), mode="edge")
    padded_mask = np.pad(mask, 1, mode="constant", constant_values=False)
    same_any = np.zeros((h, w), dtype=bool)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            if dy == 0 and dx == 0:
                continue
            neigh = padded[1 + dy : 1 + dy + h, 1 + dx : 1 + dx + w]
            nmask = padded_mask[1 + dy : 1 + dy + h, 1 + dx : 1 + dx + w]
            same_any |= nmask & np.all(neigh == rgb, axis=-1)
    return mask & ~same_any


def edge_mask(mask: np.ndarray) -> np.ndarray:
    """不透明領域のうち、4 近傍に透過 pixel（または画像端）を持つ pixel。"""
    padded = np.pad(mask, 1, mode="constant", constant_values=False)
    h, w = mask.shape
    inner = (
        padded[0:h, 1 : w + 1]
        & padded[2 : h + 2, 1 : w + 1]
        & padded[1 : h + 1, 0:w]
        & padded[1 : h + 1, 2 : w + 2]
    )
    return mask & ~inner


def connected_components(mask: np.ndarray) -> tuple[np.ndarray, int]:
    """4 連結の連結成分ラベリング (scipy 非依存、小画像向け)。"""
    h, w = mask.shape
    labels = np.zeros((h, w), dtype=np.int32)
    current = 0
    for y in range(h):
        for x in range(w):
            if not mask[y, x] or labels[y, x]:
                continue
            current += 1
            stack = [(y, x)]
            labels[y, x] = current
            while stack:
                cy, cx = stack.pop()
                for ny, nx in ((cy - 1, cx), (cy + 1, cx), (cy, cx - 1), (cy, cx + 1)):
                    if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not labels[ny, nx]:
                        labels[ny, nx] = current
                        stack.append((ny, nx))
    return labels, current


def write_json(data: dict, path: str | None) -> None:
    text = json.dumps(data, ensure_ascii=False, indent=2)
    if path:
        Path(path).parent.mkdir(parents=True, exist_ok=True)
        Path(path).write_text(text + "\n")
    else:
        print(text)


def die(message: str, code: int = 2) -> None:
    print(f"Error: {message}", file=sys.stderr)
    sys.exit(code)
