---
name: drawio-svg-preview
description: draw.io SVG内のembedded mxfileを抽出し、Confluence/diagrams.net相当の見え方をPNGで確認する。Confluence・GitHub・ローカルSVG previewで文字色、label、背景、埋め込み画像の見え方がずれる場合や、.drawio.svgをDesign Docに埋め込む前の確認で使用。
---

# draw.io SVG Preview

`.drawio.svg`は見た目用のSVG markupとは別に、`content`属性へdraw.ioのmxfileを埋め込める。Confluence/diagrams.net viewerはこのmxfileを再レンダリングすることがあり、`rsvg-convert`やブラウザ表示だけでは崩れを検出できない。

## 使い方

```bash
python3 ~/.claude/skills/drawio-svg-preview/scripts/preview_drawio_svg.py docs/architecture-diagram/example.drawio.svg
```

出力されたPNGを確認し、それをConfluence相当のpreviewとして扱う。

## Renderer

- `auto`: Dockerが使えればDocker、使えなければローカルdraw.io CLIを使う。
- `docker`: `rlespinasse/drawio-export:v4.51.0`を使う。macOS/Linux/WindowsのDocker環境で動かすための標準経路。
- `local`: `/Applications/draw.io.app/Contents/MacOS/draw.io`など、ローカルのdraw.io Desktop CLIを直接使う。

Docker Desktop/Rancher Desktopでは`/tmp`がvolume mountできないことがあるため、既定の一時ディレクトリは`~/.cache/drawio-svg-preview/`配下に作る。sandbox等で作成できない場合は現在の作業ディレクトリ配下へfallbackする。

## よく見るべき崩れ

- 黒背景に黒文字、または白背景labelが出る場合: embedded mxfile側の`fontColor`や`labelBackgroundColor`を直す。
- BigQueryなどのアイコンが壊れる場合: nested SVG/data URI画像がdraw.io exportで再解釈できていない可能性が高い。安定したPNGか単純な図形へ置き換える。
- visible SVGのpreviewだけ正常な場合: `content`属性のmxfile側が古い可能性がある。

## Docker image

`docker/Dockerfile`は利用イメージを固定・明示するための薄い定義。通常はscriptの`--docker-image`既定値をそのまま使えばよい。
