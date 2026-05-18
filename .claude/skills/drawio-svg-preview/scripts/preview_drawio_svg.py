#!/usr/bin/env python3
"""Render embedded draw.io mxfile content from a .drawio.svg."""

from __future__ import annotations

import argparse
import html
import re
import shutil
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path


DEFAULT_DOCKER_IMAGE = "rlespinasse/drawio-export:v4.51.0"
DEFAULT_MACOS_DRAWIO_BIN = Path("/Applications/draw.io.app/Contents/MacOS/draw.io")
DEFAULT_CACHE_ROOT = Path.home() / ".cache" / "drawio-svg-preview"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Extract embedded mxfile content from a .drawio.svg and export it to PNG."
    )
    parser.add_argument("svg", type=Path, help="Path to a .drawio.svg file")
    parser.add_argument(
        "--renderer",
        choices=("auto", "docker", "local"),
        default="auto",
        help="Renderer backend. Default: auto",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=None,
        help="Directory for generated files. Defaults to a local temp directory.",
    )
    parser.add_argument(
        "--docker-image",
        default=DEFAULT_DOCKER_IMAGE,
        help=f"Docker image for draw.io export. Default: {DEFAULT_DOCKER_IMAGE}",
    )
    parser.add_argument(
        "--drawio-bin",
        type=Path,
        default=DEFAULT_MACOS_DRAWIO_BIN,
        help=f"Local draw.io CLI path. Default: {DEFAULT_MACOS_DRAWIO_BIN}",
    )
    parser.add_argument(
        "--keep-drawio",
        action="store_true",
        help="Keep the extracted .drawio file. The PNG is always kept.",
    )
    return parser.parse_args()


def extract_content(svg_path: Path) -> str:
    svg_text = svg_path.read_text(encoding="utf-8")
    match = re.search(r'content="([^"]*)"', svg_text)
    if not match:
        raise ValueError(f"{svg_path} does not contain an embedded draw.io content attribute")

    content = html.unescape(match.group(1))
    try:
        ET.fromstring(content)
    except ET.ParseError as exc:
        raise ValueError(f"embedded draw.io content is not valid XML: {exc}") from exc
    return content


def choose_renderer(requested: str) -> str:
    if requested != "auto":
        return requested
    if shutil.which("docker") and docker_is_available():
        return "docker"
    return "local"


def docker_is_available() -> bool:
    try:
        subprocess.run(
            ["docker", "version", "--format", "{{.Server.Version}}"],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        return True
    except (OSError, subprocess.CalledProcessError):
        return False


def make_output_dir(output_dir: Path | None, renderer: str) -> Path:
    if output_dir is not None:
        output_dir.mkdir(parents=True, exist_ok=True)
        return output_dir.resolve()

    if renderer == "docker":
        try:
            DEFAULT_CACHE_ROOT.mkdir(parents=True, exist_ok=True)
            return Path(tempfile.mkdtemp(prefix="preview-", dir=DEFAULT_CACHE_ROOT)).resolve()
        except OSError:
            return Path(tempfile.mkdtemp(prefix=".drawio-svg-preview-", dir=Path.cwd())).resolve()
    return Path(tempfile.mkdtemp(prefix="drawio-svg-preview-")).resolve()


def output_paths(svg_path: Path, output_dir: Path) -> tuple[Path, Path]:
    stem = svg_path.name
    if stem.endswith(".drawio.svg"):
        stem = stem[: -len(".drawio.svg")]
    else:
        stem = svg_path.stem
    return output_dir / f"{stem}.drawio", output_dir / f"{stem}.drawio.png"


def render_with_local(drawio_bin: Path, drawio_path: Path, png_path: Path) -> list[Path]:
    if not drawio_bin.exists():
        raise FileNotFoundError(f"draw.io CLI not found: {drawio_bin}")
    subprocess.run(
        [
            str(drawio_bin),
            "--export",
            "--format",
            "png",
            "--output",
            str(png_path),
            str(drawio_path),
        ],
        check=True,
    )
    return [png_path]


def render_with_docker(image: str, drawio_path: Path, png_path: Path) -> list[Path]:
    work_dir = drawio_path.parent.resolve()
    container_drawio = f"/data/{drawio_path.name}"
    container_out = "/out"
    before = {path: path.stat().st_mtime_ns for path in work_dir.glob("*.png")}
    subprocess.run(
        [
            "docker",
            "run",
            "--rm",
            "-v",
            f"{work_dir}:/data",
            "-v",
            f"{work_dir}:/out",
            image,
            "-f",
            "png",
            "-o",
            container_out,
            "--remove-page-suffix",
            container_drawio,
        ],
        check=True,
    )

    generated_paths = sorted(
        path
        for path in work_dir.glob(f"{drawio_path.stem}*.png")
        if path not in before or path.stat().st_mtime_ns != before[path]
    )
    if not generated_paths:
        raise FileNotFoundError(f"Docker renderer did not create PNG files for: {drawio_path}")

    if len(generated_paths) == 1:
        generated = generated_paths[0]
        if generated != png_path:
            generated.replace(png_path)
        return [png_path]

    return generated_paths


def main() -> int:
    args = parse_args()
    svg_path = args.svg.expanduser().resolve()
    if not svg_path.exists():
        print(f"error: file not found: {svg_path}", file=sys.stderr)
        return 2

    try:
        renderer = choose_renderer(args.renderer)
        output_dir = make_output_dir(args.output_dir, renderer)
        drawio_path, png_path = output_paths(svg_path, output_dir)
        drawio_path.write_text(extract_content(svg_path), encoding="utf-8")

        if renderer == "docker":
            png_paths = render_with_docker(args.docker_image, drawio_path, png_path)
        else:
            png_paths = render_with_local(args.drawio_bin.expanduser(), drawio_path, png_path)

        if not args.keep_drawio:
            drawio_path.unlink(missing_ok=True)
    except Exception as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    print(f"renderer: {renderer}")
    for path in png_paths:
        print(f"png: {path}")
    if args.keep_drawio:
        print(f"drawio: {drawio_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
