#!/usr/bin/env bash
set -euo pipefail

# Build a macOS .icns from a single PNG source. Crops to a 1024×1024
# rounded-rect (radius 180, ~17.5% — close to the macOS Big Sur+ squircle)
# then emits the standard 10-image .iconset and runs `iconutil -c icns`.

ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="${1:-$ROOT/docs/icon-source.png}"
OUT_ICNS="${2:-$ROOT/docs/AppIcon.icns}"
RADIUS="${3:-180}"

if [[ ! -f "$SRC" ]]; then
    echo "Source image not found: $SRC" >&2
    exit 1
fi

if ! command -v magick >/dev/null 2>&1; then
    echo "ImageMagick (magick) is required. brew install imagemagick" >&2
    exit 1
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "==> Resizing source to 1024×1024"
magick "$SRC" -resize 1024x1024^ -gravity center -extent 1024x1024 \
    -alpha set "$WORK/full.png"

echo "==> Building rounded-rect mask (radius=$RADIUS)"
magick -size 1024x1024 xc:none \
    -fill white -draw "roundrectangle 0,0 1023,1023 $RADIUS,$RADIUS" \
    "$WORK/mask.png"

echo "==> Applying mask"
magick "$WORK/full.png" "$WORK/mask.png" \
    -compose DstIn -composite \
    "$WORK/rounded.png"

ICONSET="$WORK/AppIcon.iconset"
mkdir -p "$ICONSET"

# Standard macOS .iconset images.
declare -a ENTRIES=(
    "16   icon_16x16.png"
    "32   icon_16x16@2x.png"
    "32   icon_32x32.png"
    "64   icon_32x32@2x.png"
    "128  icon_128x128.png"
    "256  icon_128x128@2x.png"
    "256  icon_256x256.png"
    "512  icon_256x256@2x.png"
    "512  icon_512x512.png"
    "1024 icon_512x512@2x.png"
)
echo "==> Rendering iconset"
for entry in "${ENTRIES[@]}"; do
    size="${entry%% *}"
    name="${entry##* }"
    sips -z "$size" "$size" "$WORK/rounded.png" --out "$ICONSET/$name" >/dev/null
done

echo "==> Compiling .icns"
iconutil -c icns "$ICONSET" -o "$OUT_ICNS"

echo "==> Built $OUT_ICNS ($(du -h "$OUT_ICNS" | cut -f1))"
