#!/bin/zsh
# Create, debug, stop, and report the isolated Gridline version copies.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
VERSIONS_DIR="$ROOT/gridline_versions"
STATUS_FILE="$VERSIONS_DIR/runtime-status.json"
mkdir -p "$VERSIONS_DIR"

versions_list() {
  versions=("$VERSIONS_DIR"/version_*(N/))
}

version_processes() {
  local version_number="${1#version_}"
  GRIDLINE_PROCESS="Gridline${version_number}"
  DEBUG_PROCESS="MyLLMDebug${version_number}"
  GRIDLINE_ID="local.gridline.terminal.version${version_number}"
  DEBUG_ID="local.myllm.debuginspector.version${version_number}"
}

find_watcher_pid() {
  local version_path="$1"
  local pid_file="$version_path/gridline_debug/build/watch.pid"
  local watcher_pid=""
  if [[ -f "$pid_file" ]]; then
    watcher_pid="$(<"$pid_file")"
    if [[ "$watcher_pid" == <-> ]]; then
      local command
      command="$(ps -p "$watcher_pid" -o command= 2>/dev/null || true)"
      if [[ "$command" == *"watch-build.sh"* && "$command" == *"$version_path"* ]]; then
        print -r -- "$watcher_pid"
        return 0
      fi
    fi
  fi
  return 1
}

watcher_is_running() {
  [[ -n "$(find_watcher_pid "$1" 2>/dev/null || true)" ]]
}

refresh_status() {
  versions_list
  local timestamp
  timestamp="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  local json="{\"updatedAt\":\"$timestamp\",\"versions\":["
  local first=1
  for version_path in "${versions[@]}"; do
    local label="${version_path:t}"
    version_processes "$label"
    local gridline_state="stopped"
    local debug_state="stopped"
    local watcher_state="stopped"
    local gridline_pid="" debug_pid="" watcher_pid=""
    gridline_pid="$(pgrep -x "$GRIDLINE_PROCESS" 2>/dev/null | head -n 1 || true)"
    debug_pid="$(pgrep -x "$DEBUG_PROCESS" 2>/dev/null | head -n 1 || true)"
    watcher_pid="$(find_watcher_pid "$version_path" 2>/dev/null || true)"
    [[ -z "$gridline_pid" ]] || gridline_state="running"
    [[ -z "$debug_pid" ]] || debug_state="running"
    [[ -z "$watcher_pid" ]] || watcher_state="running"
    (( first )) || json+=","
    json+="{\"version\":\"$label\",\"gridline\":\"$gridline_state\",\"gridlinePid\":\"$gridline_pid\",\"gridlineDebug\":\"$debug_state\",\"gridlineDebugPid\":\"$debug_pid\",\"watcher\":\"$watcher_state\",\"watcherPid\":\"$watcher_pid\",\"gridlineBundleId\":\"$GRIDLINE_ID\",\"gridlineDebugBundleId\":\"$DEBUG_ID\",\"path\":\"$version_path\"}"
    first=0
  done
  json+="]}"
  printf '%s\n' "$json" > "$STATUS_FILE"
}

show_versions() {
  versions_list
  if (( ${#versions[@]} == 0 )); then
    echo "  No saved versions yet."
    return
  fi
  local index=1
  for version_path in "${versions[@]}"; do
    local label="${version_path:t}"
    version_processes "$label"
    local states=()
    pgrep -x "$GRIDLINE_PROCESS" >/dev/null 2>&1 && states+=("Gridline running") || states+=("Gridline stopped")
    pgrep -x "$DEBUG_PROCESS" >/dev/null 2>&1 && states+=("Gridline Debug running") || states+=("Gridline Debug stopped")
    watcher_is_running "$version_path" && states+=("hot reload running") || states+=("hot reload stopped")
    printf '  %d) %s — %s\n' "$index" "$label" "${(j:; :)states}"
    (( index += 1 ))
  done
}

select_version() {
  versions_list
  if (( ${#versions[@]} == 0 )); then
    echo "No saved versions yet. Choose Create first."
    return 1
  fi
  show_versions
  local selection
  read -r "selection?Choose a version number: "
  if [[ ! "$selection" == <-> ]] || (( selection < 1 || selection > ${#versions[@]} )); then
    echo "That version selection is not valid." >&2
    return 2
  fi
  selected_version="${versions[$selection]}"
}

run_version() {
  local version_path="$1"
  local label="${version_path:t}"
  echo "Starting $label and its paired Gridline Debug. Press Ctrl-C to stop the watcher."
  "$version_path/start.sh" &
  local watcher_job=$!
  while kill -0 "$watcher_job" 2>/dev/null; do
    refresh_status
    sleep 2
  done
  wait "$watcher_job" || true
  refresh_status
}

create_version() {
  local number=1
  while [[ -d "$VERSIONS_DIR/version_$number" ]]; do
    (( number += 1 ))
  done
  local label="version_$number"
  local destination="$VERSIONS_DIR/$label"
  mkdir -p "$destination"
  rsync -a --exclude='/.build/' --exclude='/*.app/' "$ROOT/gridline/" "$destination/gridline/"
  rsync -a --exclude='/Inspector/.build/' --exclude='/*.app/' --exclude='/events.jsonl' --exclude='/build/' --exclude='/reports/*' "$ROOT/gridline_debug/" "$destination/gridline_debug/"
  rsync -a "$ROOT/logo/" "$destination/logo/"
  cp "$ROOT/start.sh" "$destination/start.sh"
  cat > "$destination/AGENTS.md" <<VERSION_AGENTS
# Coding instructions for $label

This is an isolated version copy. Keep Gridline app code in gridline/ and Gridline Debug code in gridline_debug/. Reuse existing functions, views, and styles; extend existing code instead of duplicating it. Keep debug events and reports inside this copy. Run ./start.sh from this folder to build, launch, and hot-reload only $label. Its paired Gridline Debug filters for this copy's Gridline bundle ID.
VERSION_AGENTS
  cat > "$destination/README.md" <<VERSION_README
# Gridline $label

The root [README.md](../../README.md) is the authoritative guide for choosing a target, launchers, hot reload, PID pairing, and the LLM prompt. This folder is an isolated copy.

Edit only gridline/ or gridline_debug/ here for $label. Start its paired apps and hot reload with ./start.sh from this folder, or select $label through the root ./start_versions.sh menu. Its bundle IDs, workspace data, debug events, and PIDs are separate from the main app and other versions.
VERSION_README
  printf '%s\n' "$label" > "$destination/VERSION"
  chmod +x "$destination/start.sh" "$destination/gridline/build-app.sh" "$destination/gridline/build-app-icon.sh" "$destination/gridline_debug/build-inspector.sh" "$destination/gridline_debug/watch-build.sh"
  echo "Created $destination"
  refresh_status
  run_version "$destination"
}

debug_version() {
  if ! select_version; then exit 2; fi
  run_version "$selected_version"
}

stop_version() {
  if ! select_version; then exit 2; fi
  local version_path="$selected_version"
  local label="${version_path:t}"
  version_processes "$label"

  # Stop the version's watcher first so it cannot relaunch either app.
  if watcher_is_running "$version_path"; then
    local watcher_pid
    watcher_pid="$(find_watcher_pid "$version_path" 2>/dev/null || true)"
    [[ -z "$watcher_pid" ]] || kill -TERM "$watcher_pid" 2>/dev/null || true
    for attempt in {1..20}; do
      watcher_is_running "$version_path" || break
      sleep 0.25
    done
  fi
  rm -f "$version_path/gridline_debug/build/watch.pid"

  osascript -e "tell application id \"$GRIDLINE_ID\" to quit" >/dev/null 2>&1 || true
  osascript -e "tell application id \"$DEBUG_ID\" to quit" >/dev/null 2>&1 || true
  for attempt in {1..20}; do
    if ! pgrep -x "$GRIDLINE_PROCESS" >/dev/null 2>&1 && ! pgrep -x "$DEBUG_PROCESS" >/dev/null 2>&1; then break; fi
    sleep 0.25
  done
  pkill -TERM -x "$GRIDLINE_PROCESS" >/dev/null 2>&1 || true
  pkill -TERM -x "$DEBUG_PROCESS" >/dev/null 2>&1 || true
  refresh_status
  echo "Stopped $label's Gridline, Gridline Debug, and hot-reload watcher. Its source and saved debug data remain in $version_path."
}

refresh_status
cat <<'MENU'
Gridline version manager
  1) Create a new isolated version copy and start it
  2) Debug / start an existing version
  3) Stop a version's Gridline, Gridline Debug, and watcher
MENU
show_versions
read -r "choice?Choose Create, Debug, or Stop (1/2/3): "
case "$choice" in
  1|c|C|create|Create) create_version ;;
  2|d|D|debug|Debug) debug_version ;;
  3|s|S|stop|Stop) stop_version ;;
  *) echo "Choose 1 (Create), 2 (Debug), or 3 (Stop)." >&2; exit 2 ;;
esac
