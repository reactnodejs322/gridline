#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SOURCE="$1"
OUTPUT="$2"
NAME="$3"
ICONSETS="$ROOT/.build/iconsets"
ICONSET="$ICONSETS/$NAME.iconset"

mkdir -p "$ICONSET" "$(dirname "$OUTPUT")"
make_size() {
  local size="$1"
  local filename="icon_${size}x${size}.png"
  sips -z "$size" "$size" "$SOURCE" --out "$ICONSET/$filename" >/dev/null
}

make_size 16
sips -z 32 32 "$SOURCE" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
make_size 32
sips -z 64 64 "$SOURCE" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
make_size 128
sips -z 256 256 "$SOURCE" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
make_size 256
sips -z 512 512 "$SOURCE" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
make_size 512
sips -z 1024 1024 "$SOURCE" --out "$ICONSET/icon_512x512@2x.png" >/dev/null

iconutil -c icns "$ICONSET" -o "$OUTPUT"
