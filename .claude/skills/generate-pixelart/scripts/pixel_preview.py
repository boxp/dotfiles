#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["pillow>=10", "numpy>=1.26"]
# ///
"""原寸と整数倍 nearest 拡大を並べた比較シートを作る (目視検査・Owner 提示用)。

  uv run pixel_preview.py -o sheet.png --scales 1,4 --bg '#404040' old=old.png new=new.png
  uv run pixel_preview.py -o g2.png --g2 face=face_g2.png     # 576x288 黒背景の G2 画面想定で 1x/2x

各列が 1 つの画像、各行が 1 つの倍率。拡大は常に nearest (補間しない)。
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw

CHECKER = ((200, 200, 200), (150, 150, 150))


def checker(size: tuple[int, int], cell: int = 8) -> Image.Image:
    im = Image.new("RGB", size, CHECKER[0])
    d = ImageDraw.Draw(im)
    for y in range(0, size[1], cell):
        for x in range(0, size[0], cell):
            if ((x // cell) + (y // cell)) % 2:
                d.rectangle([x, y, x + cell - 1, y + cell - 1], fill=CHECKER[1])
    return im


def background(size: tuple[int, int], bg: str) -> Image.Image:
    if bg == "checker":
        return checker(size)
    if bg == "black":
        return Image.new("RGB", size, (0, 0, 0))
    bg = bg.lstrip("#")
    return Image.new("RGB", size, tuple(int(bg[i : i + 2], 16) for i in (0, 2, 4)))


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("items", nargs="+", help="label=path.png")
    ap.add_argument("-o", "--output", required=True)
    ap.add_argument("--scales", default="1,4")
    ap.add_argument("--bg", default="checker", help="checker | black | #rrggbb")
    ap.add_argument("--g2", action="store_true", help="576x288 の黒背景 (Even G2 画面想定) に左上配置して 1x と 2x を並べる")
    ap.add_argument("--gap", type=int, default=12)
    args = ap.parse_args()

    items = []
    for spec in args.items:
        label, _, path = spec.partition("=")
        if not path:
            label, path = Path(spec).stem, spec
        items.append((label, Image.open(path).convert("RGBA")))

    scales = [int(s) for s in args.scales.split(",")]
    if args.g2:
        scales = [1, 2]
        args.bg = "black"
    gap = args.gap
    label_h = 14
    cells = []  # (label, scale, image)
    for label, im in items:
        for s in scales:
            if args.g2:
                screen = Image.new("RGBA", (576, 288), (0, 0, 0, 255))
                screen.paste(im, (0, 0), im)
                up = screen.resize((576 * s, 288 * s), Image.NEAREST)
            else:
                up = im.resize((im.width * s, im.height * s), Image.NEAREST)
            cells.append((f"{label} x{s} ({im.width}x{im.height})", s, up))

    col_w = [max(c[2].width for c in cells if c[0].startswith(lbl + " ")) for lbl, _ in items]
    row_h = [max(c[2].height for c in cells if c[1] == s) for s in scales]
    total_w = sum(col_w) + gap * (len(items) + 1)
    total_h = sum(row_h) + (label_h + gap) * len(scales) + gap
    sheet = background((total_w, total_h), args.bg)
    draw = ImageDraw.Draw(sheet)
    y = gap
    for ri, s in enumerate(scales):
        x = gap
        for ci, (label, _) in enumerate(items):
            cell = next(c for c in cells if c[1] == s and c[0].startswith(label + " "))
            text_fill = (255, 255, 255) if args.bg == "black" else (20, 20, 20)
            draw.text((x, y), cell[0], fill=text_fill)
            sheet.paste(cell[2], (x, y + label_h), cell[2])
            x += col_w[ci] + gap
        y += row_h[ri] + label_h + gap
    Path(args.output).parent.mkdir(parents=True, exist_ok=True)
    sheet.save(args.output)
    print(f"preview: {sheet.width}x{sheet.height} -> {args.output}")


if __name__ == "__main__":
    main()
