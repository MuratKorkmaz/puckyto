#!/bin/bash
# Renders Resources/icon.svg into Resources/AppIcon.icns (and the README preview).
# Run it after editing the SVG.
set -euo pipefail
cd "$(dirname "$0")/.."

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

echo "▸ rendering icon.svg"
qlmanage -t -s 1024 -o "$WORK" Resources/icon.svg >/dev/null 2>&1
MASTER="$WORK/icon.svg.png"
[ -f "$MASTER" ] || { echo "✗ could not render the SVG"; exit 1; }

echo "▸ building the iconset"
mkdir -p "$WORK/AppIcon.iconset"
while read -r size name; do
  [ -z "$size" ] && continue
  sips -z "$size" "$size" "$MASTER" --out "$WORK/AppIcon.iconset/${name}.png" >/dev/null 2>&1
done << 'SIZES'
16 icon_16x16
32 icon_16x16@2x
32 icon_32x32
64 icon_32x32@2x
128 icon_128x128
256 icon_128x128@2x
256 icon_256x256
512 icon_256x256@2x
512 icon_512x512
1024 icon_512x512@2x
SIZES

iconutil -c icns "$WORK/AppIcon.iconset" -o Resources/AppIcon.icns
sips -z 256 256 "$MASTER" --out docs/images/icon.png >/dev/null 2>&1

echo "✅ Resources/AppIcon.icns updated"
echo "   Rebuild the app for it to take effect: ./scripts/build-app.sh"
