#!/usr/bin/env bash
# generate-pixelart 支援 script のテスト。正例が pass し、違反 fixture が fail することを確認する。
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$TESTS_DIR/../scripts" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
FIX="$WORK/fixtures"
failed=0

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; failed=$((failed + 1)); }
run() { uv run --quiet "$SCRIPTS_DIR/$1" "${@:2}"; }
py() { uv run --quiet --with pillow --with numpy python "$@"; }
expect_ok() { local name="$1"; shift; if "$@" >/dev/null 2>"$WORK/err"; then pass "$name"; else fail "$name ($(cat "$WORK/err"))"; fi; }
expect_fail() { local name="$1"; shift; if "$@" >/dev/null 2>"$WORK/err"; then fail "$name (expected failure)"; else pass "$name"; fi; }
expect_fail_with() {
  local name="$1" needle="$2"; shift 2
  if "$@" >"$WORK/out" 2>"$WORK/err"; then fail "$name (expected failure)"; return; fi
  if grep -q "$needle" "$WORK/out" "$WORK/err"; then pass "$name"; else fail "$name (missing '$needle')"; cat "$WORK/err"; fi
}

uv run --quiet "$TESTS_DIR/make_fixtures.py" "$FIX" >/dev/null

CHECK="pixel_check.py"
expect_ok "check: clean fixture passes" run $CHECK "$FIX/good_24.png" --expect-size 24x24 --max-colors 8 --max-isolated 0.03 --key '#00FF00' --json "$WORK/good.json"
expect_fail_with "check: partial alpha fails" "alpha" run $CHECK "$FIX/bad_partial_alpha.png"
expect_fail_with "check: too many colors fails" "colors" run $CHECK "$FIX/bad_many_colors_isolated.png" --max-colors 8
expect_fail_with "check: isolated noise fails" "isolated" run $CHECK "$FIX/bad_many_colors_isolated.png" --max-isolated 0.03
expect_fail_with "check: green fringe fails" "fringe" run $CHECK "$FIX/bad_green_fringe.png" --key '#00FF00'
expect_ok "check: wrong size fails only when asked" run $CHECK "$FIX/good_24.png" --max-colors 8
expect_fail_with "check: wrong size fails" "size" run $CHECK "$FIX/good_24.png" --expect-size 32x32
expect_ok "check: 4x nearest upscale passes" run $CHECK "$FIX/good_scaled_4x.png" --scale 4
expect_fail_with "check: broken 4x block fails" "scale" run $CHECK "$FIX/bad_scaled_4x.png" --scale 4
expect_fail_with "check: non-multiple scale fails" "scale" run $CHECK "$FIX/good_24.png" --scale 5
expect_ok "check: palette subset passes" run $CHECK "$FIX/g2_good.png" --preset g2-green16 --min-contrast 100
expect_fail_with "check: g2 off-palette and level0 fails" "palette" run $CHECK "$FIX/g2_bad.png" --preset g2-green16
expect_fail_with "check: g2 level0 opaque fails" "透過 level" run $CHECK "$FIX/g2_bad.png" --preset g2-green16
expect_fail_with "check: g2 too big fails" "288x144" run $CHECK "$FIX/g2_too_big.png" --preset g2-green16
expect_fail_with "check: low contrast fails" "contrast" run $CHECK "$FIX/g2_too_big.png" --min-contrast 50 --allow-opaque-transparent-level
expect_ok "check: mouth-only variant within drift" run $CHECK "$FIX/variant_mouth.png" --compare "$FIX/good_24.png" --max-drift 0.1
expect_fail_with "check: shifted variant exceeds drift" "drift" run $CHECK "$FIX/variant_drift.png" --compare "$FIX/good_24.png" --max-drift 0.1
expect_fail_with "check: compare size mismatch fails" "寸法" run $CHECK "$FIX/g2_good.png" --compare "$FIX/good_24.png"

# JSON report の中身
if py -c "import json,sys; d=json.load(open('$WORK/good.json')); sys.exit(0 if d['ok'] and d['colors']==5 and d['alpha_values']==[0,255] else 1)"; then
  pass "check: json report has ok/colors/alpha"
else
  fail "check: json report has ok/colors/alpha"
fi

# snap: AI 風 (位相ずれ + ぼかし + ノイズ) 入力から 24x24 を復元し、キー色除去後に期待値と一致する
expect_ok "snap: runs" run pixel_snap.py "$FIX/ai_like_24.png" -o "$WORK/snapped.png" --grid 25x25 --report "$WORK/snap.json"
expect_ok "cleanup: key + trim + canvas" run pixel_cleanup.py "$WORK/snapped.png" -o "$WORK/snapped_clean.png" --key '#00FF00' --key-tol 60 --trim --canvas 24x24 --anchor top
expect_ok "cleanup: trim expected the same way" run pixel_cleanup.py "$FIX/ai_like_24_expected.png" -o "$WORK/expected_clean.png" --trim --canvas 24x24 --anchor top
if py - "$WORK/snapped_clean.png" "$WORK/expected_clean.png" <<'EOF'
import sys
import numpy as np
from PIL import Image
a = np.array(Image.open(sys.argv[1]).convert("RGBA")).astype(int)
b = np.array(Image.open(sys.argv[2]).convert("RGBA")).astype(int)
assert a.shape == b.shape, (a.shape, b.shape)
alpha_same = (a[..., 3] == b[..., 3]).mean()
opaque = b[..., 3] > 0
color_err = np.abs(a[..., :3] - b[..., :3])[opaque].max()
print("alpha_same", alpha_same, "max_color_err", color_err)
sys.exit(0 if alpha_same >= 0.98 and color_err <= 24 else 1)
EOF
then pass "snap: recovers 24x24 art from blurred, offset upscale"; else fail "snap: recovers 24x24 art"; fi

# snap の推定ピッチが真値 (13.3) に近い
if py -c "import json,sys; d=json.load(open('$WORK/snap.json')); p=d['pitch']; sys.exit(0 if all(abs(v-13.3)<0.4 for v in p) else 1)"; then
  pass "snap: estimated pitch within 0.4px of 13.3"
else
  fail "snap: estimated pitch ($(cat "$WORK/snap.json" | tr -d '\n'))"
fi

# snap --grid auto: 13.3px の格子を自動検出して同じ結果になる
expect_ok "snap: auto grid runs" run pixel_snap.py "$FIX/ai_like_24.png" -o "$WORK/auto.png" --grid auto --report "$WORK/auto.json"
if py -c "import json,sys; d=json.load(open('$WORK/auto.json')); sys.exit(0 if d['grid']==[25,25] and all(abs(v-13.3)<0.4 for v in d['pitch']) and d['detected']['x']['lag']==13 else 1)"; then
  pass "snap: auto grid detects 25x25 at ~13.3px"
else
  fail "snap: auto grid ($(tr -d '\n' < "$WORK/auto.json"))"
fi
expect_fail_with "snap: auto grid refuses non-grid image" "周期" run pixel_snap.py "$FIX/gradient_16x32.png" -o "$WORK/nogrid.png" --grid auto
# snap --like: 基準の report と同じ格子で snap し、同一入力なら同一出力
expect_ok "snap: like runs" run pixel_snap.py "$FIX/ai_like_24.png" -o "$WORK/like.png" --like "$WORK/auto.json" --report "$WORK/like.json"
if cmp -s "$WORK/auto.png" "$WORK/like.png"; then pass "snap: like reproduces auto output"; else fail "snap: like reproduces auto output"; fi
expect_fail_with "snap: like rejects different input size" "寸法" run pixel_snap.py "$FIX/good_24.png" -o "$WORK/like2.png" --like "$WORK/auto.json"

# composite: 矩形内だけ差分を採用し、漂流検査を通す
expect_ok "composite: mouth region" run pixel_composite.py "$FIX/good_24.png" "$FIX/variant_drift.png" -o "$WORK/comp.png" --region 8,14,16,18 --report "$WORK/comp.json"
expect_ok "composite: result within drift" run $CHECK "$WORK/comp.png" --compare "$FIX/good_24.png" --max-drift 0.1
if py -c "
import numpy as np; from PIL import Image, ImageChops
a=Image.open('$WORK/comp.png'); b=Image.open('$FIX/good_24.png'); v=Image.open('$FIX/variant_drift.png')
import sys
A=np.array(a); B=np.array(b); V=np.array(v)
outside=np.ones(A.shape[:2],bool); outside[14:18,8:16]=False
sys.exit(0 if np.array_equal(A[outside],B[outside]) and np.array_equal(A[14:18,8:16],V[14:18,8:16]) else 1)"; then
  pass "composite: outside region equals base, inside equals variant"
else
  fail "composite: outside region equals base, inside equals variant"
fi
expect_fail_with "composite: region out of bounds" "範囲外" run pixel_composite.py "$FIX/good_24.png" "$FIX/variant_drift.png" -o "$WORK/comp2.png" --region 0,0,30,30
expect_fail_with "composite: size mismatch" "寸法" run pixel_composite.py "$FIX/good_24.png" "$FIX/g2_good.png" -o "$WORK/comp3.png" --region 0,0,4,4

# cleanup: fringe / 飛び地 / 孤立ノイズを直して check が通る。ハイライト点は保護される
expect_fail "cleanup: dirty fixture fails check before cleanup" run $CHECK "$FIX/dirty_24.png" --key '#00FF00' --max-colors 8 --max-isolated 0.03
expect_ok "cleanup: runs" run pixel_cleanup.py "$FIX/dirty_24.png" -o "$WORK/clean.png" --key '#00FF00' --key-tol 60 --min-island 2 --defringe 150 --despeckle --protect-bright
expect_ok "cleanup: cleaned fixture passes check" run $CHECK "$WORK/clean.png" --key '#00FF00' --max-colors 8 --max-isolated 0.03 --expect-size 24x24
if py -c "
import numpy as np; from PIL import Image
a=np.array(Image.open('$WORK/clean.png').convert('RGBA'))
import sys; sys.exit(0 if tuple(a[12,9,:3])==(255,240,120) and tuple(a[20,5,:3])!=(123,45,67) and a[1,1,3]==0 else 1)"; then
  pass "cleanup: highlight kept, noise replaced, island removed"
else
  fail "cleanup: highlight kept, noise replaced, island removed"
fi

# key_out: 輪郭に食い込んだ緑寄り pixel は透過にせず周囲色で復元される
expect_ok "cleanup: bite fixture runs" run pixel_cleanup.py "$FIX/bite_24.png" -o "$WORK/bite.png" --key '#00FF00' --key-tol 100 --defringe 140
if py -c "
import numpy as np; from PIL import Image; import sys
a=np.array(Image.open('$WORK/bite.png').convert('RGBA')); g=np.array(Image.open('$FIX/good_24.png').convert('RGBA'))
import json; pts=[tuple(p) for p in json.load(open('$FIX/bite_24_points.json'))]
ok=all(a[y,x,3]==255 and tuple(a[y,x,:3])!=(40,200,60) for y,x in pts) and np.array_equal(a[...,3], g[...,3])
sys.exit(0 if ok else 1)"; then
  pass "cleanup: outline bites restored, silhouette identical to original"
else
  fail "cleanup: outline bites restored, silhouette identical to original"
fi
expect_ok "cleanup: bite result passes fringe check" run $CHECK "$WORK/bite.png" --key '#00FF00' --fringe-tol 100 --expect-size 24x24

# palette: 色数量子化 / 固定パレット / G2 preset
expect_ok "palette: quantize to 6 colors" run pixel_palette.py "$FIX/gradient_16x32.png" -o "$WORK/q6.png" --colors 6
expect_ok "palette: quantized passes max-colors 6 with alpha kept" run $CHECK "$WORK/q6.png" --max-colors 6
expect_ok "palette: fixed palette mapping" run pixel_palette.py "$FIX/gradient_16x32.png" -o "$WORK/fixed.png" --palette '#000000,#ff0000,#00ff00,#0000ff,#ffffff'
expect_ok "palette: mapped image is subset of palette" run $CHECK "$WORK/fixed.png" --palette '#000000,#ff0000,#00ff00,#0000ff,#ffffff'
expect_ok "palette: g2-green16 preset" run pixel_palette.py "$FIX/good_24.png" -o "$WORK/g2.png" --preset g2-green16
expect_ok "palette: g2 output passes preset check" run $CHECK "$WORK/g2.png" --preset g2-green16 --expect-size 24x24 --min-contrast 60
expect_ok "palette: g2 floor 0 produces opaque level0 (explicitly allowed)" run pixel_palette.py "$FIX/good_24.png" -o "$WORK/g2_floor0.png" --preset g2-green16 --floor 0
expect_fail_with "palette: g2 floor 0 is caught by check" "透過 level" run $CHECK "$WORK/g2_floor0.png" --preset g2-green16

# preview sheet
expect_ok "preview: sheet" run pixel_preview.py -o "$WORK/sheet.png" --scales 1,4 "a=$FIX/good_24.png" "b=$WORK/clean.png"
expect_ok "preview: g2 screen" run pixel_preview.py -o "$WORK/g2sheet.png" --g2 "face=$WORK/g2.png"
[ -s "$WORK/sheet.png" ] && [ -s "$WORK/g2sheet.png" ] && pass "preview: files written" || fail "preview: files written"

echo
if [ "$failed" -eq 0 ]; then echo "All tests passed"; else echo "$failed test(s) failed"; exit 1; fi
