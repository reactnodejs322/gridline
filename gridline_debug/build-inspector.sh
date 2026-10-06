#!/bin/zsh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/gridline_debug/Inspector"
CONFIGURATION="${1:-release}"
VERSION_LABEL=""
VERSION_NUMBER=""
INSPECTOR_ID="local.myllm.debuginspector"
GRIDLINE_ID="local.gridline.terminal"
GRIDLINE_DISPLAY_NAME="Gridline"
EXECUTABLE_NAME="MyLLMDebug"
DISPLAY_NAME="Gridline Debug"
if [[ -f "$ROOT/VERSION" ]]; then
  VERSION_LABEL="$(<"$ROOT/VERSION")"
  if [[ "$VERSION_LABEL" != version_<-> ]]; then
    echo "Invalid VERSION value: $VERSION_LABEL" >&2
    exit 1
  fi
  VERSION_NUMBER="${VERSION_LABEL#version_}"
  INSPECTOR_ID="local.myllm.debuginspector.version${VERSION_NUMBER}"
  GRIDLINE_ID="local.gridline.terminal.version${VERSION_NUMBER}"
  EXECUTABLE_NAME="MyLLMDebug${VERSION_NUMBER}"
  VERSION_DISPLAY="Version ${VERSION_NUMBER}"
  GRIDLINE_DISPLAY_NAME="Gridline ${VERSION_DISPLAY}"
  DISPLAY_NAME="Gridline Debug ${VERSION_DISPLAY}"
fi
swift build -c "$CONFIGURATION"
APP="$ROOT/gridline_debug/$DISPLAY_NAME.app"
LEGACY_APP="$ROOT/gridline_debug/Inspector.app"
LEGACY_GENERIC_APP="$ROOT/gridline_debug/Gridline Debug.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/$CONFIGURATION/MyLLMDebug" "$APP/Contents/MacOS/$EXECUTABLE_NAME"
DEBUG_ICON="$ROOT/gridline/.build/icon-source/Gridline-debug.png"
mkdir -p "$(dirname "$DEBUG_ICON")"
swift "$ROOT/gridline/tools/make-debug-icon.swift" "$ROOT/logo/Gridline2x.png" "$DEBUG_ICON"
if [[ -n "$VERSION_NUMBER" ]]; then
  VERSIONED_DEBUG_ICON="$ROOT/gridline/.build/icon-source/Gridline-debug-version.png"
  swift "$ROOT/gridline/tools/make-version-icon.swift" "$DEBUG_ICON" "$VERSIONED_DEBUG_ICON" "$VERSION_NUMBER"
  DEBUG_ICON="$VERSIONED_DEBUG_ICON"
fi
"$ROOT/gridline/build-app-icon.sh" "$DEBUG_ICON" "$APP/Contents/Resources/MyLLMDebug.icns" MyLLMDebug
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>$EXECUTABLE_NAME</string>
  <key>CFBundleIdentifier</key><string>$INSPECTOR_ID</string>
  <key>CFBundleName</key><string>$DISPLAY_NAME</string>
  <key>CFBundleDisplayName</key><string>$DISPLAY_NAME</string>
  <key>GridlineVersionLabel</key><string>$VERSION_LABEL</string>
  <key>GridlineTargetBundleID</key><string>$GRIDLINE_ID</string>
  <key>GridlineTargetName</key><string>$GRIDLINE_DISPLAY_NAME</string>
  <key>GridlineTargetPIDFile</key><string>$ROOT/gridline_debug/build/gridline.pid</string>
  <key>CFBundleIconFile</key><string>MyLLMDebug.icns</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --deep --sign - \
  --requirements "=designated => identifier \"$INSPECTOR_ID\"" \
  "$APP"
rm -rf "$LEGACY_APP"
if [[ -n "$VERSION_NUMBER" ]]; then rm -rf "$LEGACY_GENERIC_APP"; fi
echo "Built $APP"
