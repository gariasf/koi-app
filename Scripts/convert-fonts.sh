#!/usr/bin/env bash
# Regenerate Koi/Resources/Fonts/*.ttf from the design handoff's .woff2 files.
# iOS cannot bundle .woff2; it needs .ttf/.otf. This strips the woff2 wrapper.
#
# Requires: python3 + fonttools + brotli
#   pip3 install --user fonttools brotli
#
# Usage:
#   Scripts/convert-fonts.sh /path/to/design_handoff_koi_car_companion/sure-tokens/fonts
set -euo pipefail
SRC="${1:?usage: convert-fonts.sh <sure-tokens/fonts dir>}"
DST="$(cd "$(dirname "$0")/.." && pwd)/Koi/Resources/Fonts"
mkdir -p "$DST"
python3 - "$SRC" "$DST" <<'PY'
import sys, glob, os
from fontTools.ttLib import TTFont
src, dst = sys.argv[1], sys.argv[2]
for f in sorted(glob.glob(os.path.join(src, "**", "*.woff2"), recursive=True)):
    out = os.path.join(dst, os.path.splitext(os.path.basename(f))[0] + ".ttf")
    ft = TTFont(f)
    ft.flavor = None  # drop woff2 wrapper -> plain sfnt (.ttf)
    ft.save(out)
    print("->", os.path.basename(out))
PY
echo "Done. Bundled fonts must also be listed under UIAppFonts in Koi/Resources/Info.plist."
