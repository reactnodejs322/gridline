#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")"
CONFIGURATION="${1:-release}"
echo "Preparing skill_script model resources…"
python3 ../skill_script/download_models.py
VERSION_LABEL=""
VERSION_NUMBER=""
BUNDLE_ID="local.gridline.terminal"
EXECUTABLE_NAME="Gridline"
DISPLAY_NAME="Gridline"
ICON_SOURCE="../logo/Gridline2x.png"
if [[ -f ../VERSION ]]; then
  VERSION_LABEL="$(<../VERSION)"
  if [[ "$VERSION_LABEL" != version_<-> ]]; then
    echo "Invalid VERSION value: $VERSION_LABEL" >&2
    exit 1
  fi
  VERSION_NUMBER="${VERSION_LABEL#version_}"
  BUNDLE_ID="local.gridline.terminal.version${VERSION_NUMBER}"
  EXECUTABLE_NAME="Gridline${VERSION_NUMBER}"
  VERSION_DISPLAY="Version ${VERSION_NUMBER}"
  DISPLAY_NAME="Gridline ${VERSION_DISPLAY}"
  ICON_SOURCE=".build/icon-source/Gridline-version.png"
  mkdir -p "$(dirname "$ICON_SOURCE")"
  swift tools/make-version-icon.swift "../logo/Gridline2x.png" "$ICON_SOURCE" "$VERSION_NUMBER"
fi
swift build -c "$CONFIGURATION"
APP_NAME="Gridline.app"
if [[ -n "$VERSION_NUMBER" ]]; then APP_NAME="$DISPLAY_NAME.app"; fi
APP="$(pwd)/$APP_NAME"
LEGACY_GENERIC_APP="$(pwd)/Gridline.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/$CONFIGURATION/Gridline" "$APP/Contents/MacOS/$EXECUTABLE_NAME"
cp "../logo/Gridline2x.png" "$APP/Contents/Resources/Gridline2x.png"
rm -rf "$APP/Contents/Resources/usage"
mkdir -p "$APP/Contents/Resources/usage"
cp -R "usage/." "$APP/Contents/Resources/usage/"
rm -rf "$APP/Contents/Resources/skill_script"
mkdir -p "$APP/Contents/Resources/skill_script"
cp -R "../skill_script/." "$APP/Contents/Resources/skill_script/"
"$(pwd)/build-app-icon.sh" "$ICON_SOURCE" "$APP/Contents/Resources/Gridline.icns" Gridline
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>$EXECUTABLE_NAME</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleName</key><string>$DISPLAY_NAME</string>
  <key>CFBundleDisplayName</key><string>$DISPLAY_NAME</string>
  <key>GridlineVersionLabel</key><string>$VERSION_LABEL</string>
  <key>CFBundleIconFile</key><string>Gridline.icns</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSMicrophoneUsageDescription</key><string>Gridline uses the microphone while Voice todo is open to transcribe speech into editable problem notes.</string>
</dict></plist>
PLIST
codesign --force --deep --sign - \
  --requirements "=designated => identifier \"$BUNDLE_ID\"" \
  "$APP"
if [[ -n "$VERSION_NUMBER" ]]; then rm -rf "$LEGACY_GENERIC_APP"; fi
echo "Built $APP"
