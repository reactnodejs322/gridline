#!/bin/zsh
set -u
export LC_ALL=C
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/gridline_debug/build"
mkdir -p "$BUILD_DIR"
printf '%s\n' "$$" > "$BUILD_DIR/watch.pid"
STATUS="$BUILD_DIR/latest-status.json"
LOG="$BUILD_DIR/latest.log"
ERRORS="$BUILD_DIR/latest-errors.txt"
TARGET_PID_FILE="$BUILD_DIR/gridline.pid"
GRIDLINE_APP="$ROOT/gridline/Gridline.app"
INSPECTOR_APP="$ROOT/gridline_debug/Gridline Debug.app"
VERSION_LABEL=""
VERSION_NUMBER=""
GRIDLINE_ID="local.gridline.terminal"
INSPECTOR_ID="local.myllm.debuginspector"
GRIDLINE_PROCESS="Gridline"
INSPECTOR_PROCESS="MyLLMDebug"
if [[ -f "$ROOT/VERSION" ]]; then
  VERSION_LABEL="$(<"$ROOT/VERSION")"
  if [[ "$VERSION_LABEL" == version_<-> ]]; then
    VERSION_NUMBER="${VERSION_LABEL#version_}"
    VERSION_DISPLAY="Version ${VERSION_NUMBER}"
    GRIDLINE_ID="local.gridline.terminal.version${VERSION_NUMBER}"
    INSPECTOR_ID="local.myllm.debuginspector.version${VERSION_NUMBER}"
    GRIDLINE_PROCESS="Gridline${VERSION_NUMBER}"
    INSPECTOR_PROCESS="MyLLMDebug${VERSION_NUMBER}"
    GRIDLINE_APP="$ROOT/gridline/Gridline $VERSION_DISPLAY.app"
    INSPECTOR_APP="$ROOT/gridline_debug/Gridline Debug $VERSION_DISPLAY.app"
  fi
fi
first_build=1

close_existing_apps() {
  rm -f "$TARGET_PID_FILE"
  osascript -e "tell application id \"$GRIDLINE_ID\" to quit" >/dev/null 2>&1 || true
  osascript -e "tell application id \"$INSPECTOR_ID\" to quit" >/dev/null 2>&1 || true

  # Give normal app termination a moment, then enforce a clean single instance.
  for attempt in {1..20}; do
    if ! pgrep -x "$GRIDLINE_PROCESS" >/dev/null && ! pgrep -x "$INSPECTOR_PROCESS" >/dev/null; then return; fi
    sleep 0.25
  done
  pkill -TERM -x "$GRIDLINE_PROCESS" >/dev/null 2>&1 || true
  pkill -TERM -x "$INSPECTOR_PROCESS" >/dev/null 2>&1 || true
  for attempt in {1..12}; do
    if ! pgrep -x "$GRIDLINE_PROCESS" >/dev/null && ! pgrep -x "$INSPECTOR_PROCESS" >/dev/null; then return; fi
    sleep 0.25
  done
  pkill -KILL -x "$GRIDLINE_PROCESS" >/dev/null 2>&1 || true
  pkill -KILL -x "$INSPECTOR_PROCESS" >/dev/null 2>&1 || true
  for attempt in {1..12}; do
    if ! pgrep -x "$GRIDLINE_PROCESS" >/dev/null && ! pgrep -x "$INSPECTOR_PROCESS" >/dev/null; then return 0; fi
    sleep 0.25
  done
  echo "Could not close every existing app process; skipping launch to avoid duplicates." >&2
  return 1
}

open_apps() {
  open "$GRIDLINE_APP"
  open "$INSPECTOR_APP"
  local target_pid=""
  for attempt in {1..40}; do
    target_pid="$(pgrep -x "$GRIDLINE_PROCESS" 2>/dev/null | head -n 1 || true)"
    if [[ -n "$target_pid" ]]; then
      printf '%s\n' "$target_pid" > "$TARGET_PID_FILE"
      return 0
    fi
    sleep 0.25
  done
  rm -f "$TARGET_PID_FILE"
  echo "Could not find the live $VERSION_LABEL Gridline PID; Gridline Debug will not inspect another copy." >&2
  return 1
}

fingerprint() {
  {
    find "$ROOT/gridline/Sources" "$ROOT/gridline/template" "$ROOT/gridline_debug/Inspector/Sources" "$ROOT/gridline/tools" -type f -name '*.swift' -exec stat -f '%m %N' {} \; 2>/dev/null
    find "$ROOT/skill_script" -type f ! -path '*/resources/models/*' -exec stat -f '%m %N' {} \; 2>/dev/null
    find "$ROOT/gridline/usage" -type f -name '*.py' -exec stat -f '%m %N' {} \; 2>/dev/null
    stat -f '%m %N' "$ROOT/logo/Gridline2x.png" "$ROOT/gridline/Package.swift" "$ROOT/gridline/build-app-icon.sh" "$ROOT/gridline/build-app.sh" "$ROOT/gridline_debug/build-inspector.sh" "$ROOT/VERSION" 2>/dev/null
  } | sort | shasum -a 256 | cut -d ' ' -f 1
}

build_both() {
  cd "$ROOT"
  if ./gridline/build-app.sh debug >"$LOG" 2>&1 && ./gridline_debug/build-inspector.sh debug >>"$LOG" 2>&1; then
    printf 'No compiler errors. Both apps built successfully.\n' > "$ERRORS"
    printf '{"status":"success","target":"Gridline + Gridline Debug%s","time":"%s"}\n' "${VERSION_LABEL:+ ($VERSION_LABEL)}" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" > "$STATUS"
    tail -n 8 "$LOG"
    if [[ "$first_build" == 1 ]]; then
      echo "Closing existing Gridline and Gridline Debug instances…"
      close_existing_apps || return 1
      open_apps
      echo "Opened Gridline and Gridline Debug."
    else
      echo "Restarting apps to load the new native build (active terminal sessions will end)…"
      close_existing_apps || return 1
      open_apps
      echo "Reloaded Gridline and Gridline Debug."
    fi
  else
    result=$?
    rg -n 'error:|warning:|failed|Build complete|Built ' "$LOG" | tail -n 30 > "$ERRORS" || tail -n 30 "$LOG" > "$ERRORS"
    printf '{"status":"failed","target":"Gridline + Gridline Debug%s","exitCode":"%s","time":"%s"}\n' "${VERSION_LABEL:+ ($VERSION_LABEL)}" "$result" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" > "$STATUS"
    cat "$ERRORS"
  fi
}

echo "Watching ${VERSION_LABEL:-Gridline} app and skill-script sources. Logs: gridline_debug/build/latest.log. Press Ctrl-C to stop."
previous=""
while true; do
  current="$(fingerprint)"
  if [[ "$current" != "$previous" ]]; then
    previous="$current"
    echo "Source change detected; building both apps…"
    build_both
    first_build=0
  fi
  sleep 1
done
