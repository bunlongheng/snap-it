#!/usr/bin/env bash
# Build an .icns from the app icon PNG that ships in the repo.
# Usage: make-icns.sh <source.png> <destination.icns>
set -euo pipefail

source_png="${1:?source png required}"
destination="${2:?destination icns required}"

[ -f "$source_png" ] || { echo "missing icon: $source_png" >&2; exit 1; }

iconset="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$iconset"

for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$source_png" --out "$iconset/icon_${size}x${size}.png" >/dev/null
  sips -z $((size * 2)) $((size * 2)) "$source_png" \
    --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done

iconutil --convert icns "$iconset" --output "$destination"
rm -rf "$(dirname "$iconset")"
