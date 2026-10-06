#!/bin/zsh
# Stop the main Gridline pair and every isolated version, including watchers.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
typeset -a TARGETS GRIDLINE_IDS DEBUG_IDS GRIDLINE_PROCESSES DEBUG_PROCESSES WATCHER_PIDS
typeset -a APP_PIDS TREE_PIDS
typeset PROCESS_SNAPSHOT
TARGETS=("$ROOT")
GRIDLINE_IDS=("local.gridline.terminal")
DEBUG_IDS=("local.myllm.debuginspector")
GRIDLINE_PROCESSES=("Gridline")
DEBUG_PROCESSES=("MyLLMDebug")
WATCHER_PIDS=()

for version_path in "$ROOT"/gridline_versions/version_*(N/); do
  [[ -f "$version_path/VERSION" ]] || continue
  version_label="$(<"$version_path/VERSION")"
  [[ "$version_label" == version_<-> ]] || continue
  number="${version_label#version_}"
  TARGETS+=("$version_path")
  GRIDLINE_IDS+=("local.gridline.terminal.version${number}")
  DEBUG_IDS+=("local.myllm.debuginspector.version${number}")
  GRIDLINE_PROCESSES+=("Gridline${number}")
  DEBUG_PROCESSES+=("MyLLMDebug${number}")
done

watcher_pid_for() {
  local target="$1"
  local pid_file="$target/gridline_debug/build/watch.pid"
  [[ -f "$pid_file" ]] || return 1
  local watcher_pid="$(<"$pid_file")"
  [[ "$watcher_pid" == <-> ]] || return 1
  local command
  command="$(ps -p "$watcher_pid" -o command= 2>/dev/null || true)"
  [[ "$command" == *"$target/gridline_debug/watch-build.sh"* ]] || return 1
  print -r -- "$watcher_pid"
}

any_named_process_running() {
  local process_name
  for process_name in "$@"; do
    pgrep -x "$process_name" >/dev/null 2>&1 && return 0
  done
  return 1
}

append_unique_pid() {
  local pid="$1"
  local existing
  [[ "$pid" == <-> ]] || return 0
  for existing in "${APP_PIDS[@]}"; do
    [[ "$existing" == "$pid" ]] && return 0
  done
  APP_PIDS+=("$pid")
}

collect_descendants() {
  local parent_pid="$1"
  local child_pid actual_parent existing
  while read -r child_pid actual_parent; do
    if [[ "$actual_parent" == "$parent_pid" && "$child_pid" == <-> ]]; then
      collect_descendants "$child_pid"
      local found=0
      for existing in "${TREE_PIDS[@]}"; do
        [[ "$existing" == "$child_pid" ]] && found=1 && break
      done
      (( found == 1 )) || TREE_PIDS+=("$child_pid")
    fi
  done <<< "$PROCESS_SNAPSHOT"
}

pid_is_running() {
  kill -0 "$1" 2>/dev/null
}

echo "Gridline processes that will be stopped:"
for (( index = 1; index <= ${#GRIDLINE_PROCESSES}; index++ )); do
  for process_name in "${GRIDLINE_PROCESSES[$index]}" "${DEBUG_PROCESSES[$index]}"; do
    pids="$(pgrep -x "$process_name" 2>/dev/null | paste -sd ', ' - || true)"
    [[ -z "$pids" ]] || echo "  $process_name — PID(s) $pids"
  done
done
for target in "${TARGETS[@]}"; do
  if watcher_pid="$(watcher_pid_for "$target" 2>/dev/null)"; then
    WATCHER_PIDS+=("$watcher_pid")
    echo "  hot-reload watcher — PID $watcher_pid ($target)"
  fi
done

# Snapshot every process below each Gridline app and watcher before anything exits.
# This includes SwiftTerm shells and commands they launched, such as Codex.
for watcher_pid in "${WATCHER_PIDS[@]}"; do
  append_unique_pid "$watcher_pid"
done
for process_name in "${GRIDLINE_PROCESSES[@]}" "${DEBUG_PROCESSES[@]}"; do
  pids="$(pgrep -x "$process_name" 2>/dev/null || true)"
  for pid in ${(f)pids}; do append_unique_pid "$pid"; done
done
PROCESS_SNAPSHOT="$(ps -axo pid=,ppid= 2>/dev/null || true)"
for pid in "${APP_PIDS[@]}"; do collect_descendants "$pid"; done

echo "This closes every Gridline window and ends active shell/Codex terminal sessions."
if (( ${#TREE_PIDS} > 0 )); then
  echo "Also stopping ${#TREE_PIDS} child process(es) launched under Gridline or its watcher:"
  for pid in "${TREE_PIDS[@]}"; do echo "  child PID $pid"; done
fi

# Stop watchers first so they cannot relaunch apps while the script is closing them.
for watcher_pid in "${WATCHER_PIDS[@]}"; do
  kill -TERM "$watcher_pid" 2>/dev/null || true
done
for target in "${TARGETS[@]}"; do
  pid_file="$target/gridline_debug/build/watch.pid"
  for attempt in {1..20}; do
    watcher_pid="$(watcher_pid_for "$target" 2>/dev/null || true)"
    [[ -n "$watcher_pid" ]] || break
    sleep 0.25
  done
  watcher_pid="$(watcher_pid_for "$target" 2>/dev/null || true)"
  if [[ -n "$watcher_pid" ]]; then
    kill -KILL "$watcher_pid" 2>/dev/null || true
  fi
  rm -f "$pid_file"
done

# Ask each running app to quit normally, then enforce shutdown by its unique executable name.
for (( index = 1; index <= ${#GRIDLINE_IDS}; index++ )); do
  if pgrep -x "${GRIDLINE_PROCESSES[$index]}" >/dev/null 2>&1; then
    osascript -e "tell application id \"${GRIDLINE_IDS[$index]}\" to quit" >/dev/null 2>&1 || true
  fi
  if pgrep -x "${DEBUG_PROCESSES[$index]}" >/dev/null 2>&1; then
    osascript -e "tell application id \"${DEBUG_IDS[$index]}\" to quit" >/dev/null 2>&1 || true
  fi
done

# Normal app shutdown asks SwiftTerm to terminate each PTY shell. Signal any
# remaining captured descendants as well so shell-launched Codex processes exit.
for pid in "${TREE_PIDS[@]}"; do
  kill -TERM "$pid" 2>/dev/null || true
done
for attempt in {1..20}; do
  remaining=0
  for pid in "${TREE_PIDS[@]}"; do
    if pid_is_running "$pid"; then remaining=1; break; fi
  done
  (( remaining == 0 )) && break
  sleep 0.25
done
for pid in "${TREE_PIDS[@]}"; do
  pid_is_running "$pid" && kill -KILL "$pid" 2>/dev/null || true
done

for attempt in {1..20}; do
  any_named_process_running "${GRIDLINE_PROCESSES[@]}" "${DEBUG_PROCESSES[@]}" || break
  sleep 0.25
done
for process_name in "${GRIDLINE_PROCESSES[@]}" "${DEBUG_PROCESSES[@]}"; do
  pkill -TERM -x "$process_name" >/dev/null 2>&1 || true
done
for attempt in {1..20}; do
  any_named_process_running "${GRIDLINE_PROCESSES[@]}" "${DEBUG_PROCESSES[@]}" || break
  sleep 0.25
done
for process_name in "${GRIDLINE_PROCESSES[@]}" "${DEBUG_PROCESSES[@]}"; do
  pkill -KILL -x "$process_name" >/dev/null 2>&1 || true
done

# Refresh the version inventory so it does not report stopped apps as running.
versions_dir="$ROOT/gridline_versions"
mkdir -p "$versions_dir"
timestamp="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
json="{\"updatedAt\":\"$timestamp\",\"versions\":["
first=1
for version_path in "$versions_dir"/version_*(N/); do
  [[ -f "$version_path/VERSION" ]] || continue
  version_label="$(<"$version_path/VERSION")"
  [[ "$version_label" == version_<-> ]] || continue
  number="${version_label#version_}"
  gridline_pid="$(pgrep -x "Gridline${number}" 2>/dev/null | head -n 1 || true)"
  debug_pid="$(pgrep -x "MyLLMDebug${number}" 2>/dev/null | head -n 1 || true)"
  watcher_pid="$(watcher_pid_for "$version_path" 2>/dev/null || true)"
  if [[ "$first" != 1 ]]; then json+=","; fi
  gridline_state="stopped"; [[ -z "$gridline_pid" ]] || gridline_state="running"
  debug_state="stopped"; [[ -z "$debug_pid" ]] || debug_state="running"
  watcher_state="stopped"; [[ -z "$watcher_pid" ]] || watcher_state="running"
  json+="{\"version\":\"$version_label\",\"gridline\":\"$gridline_state\",\"gridlinePid\":\"$gridline_pid\",\"gridlineDebug\":\"$debug_state\",\"gridlineDebugPid\":\"$debug_pid\",\"watcher\":\"$watcher_state\",\"watcherPid\":\"$watcher_pid\",\"gridlineBundleId\":\"local.gridline.terminal.version${number}\",\"gridlineDebugBundleId\":\"local.myllm.debuginspector.version${number}\",\"path\":\"$version_path\"}"
  first=0
done
json+="]}"
print -r -- "$json" > "$versions_dir/runtime-status.json"

main_gridline_pid="$(pgrep -x Gridline 2>/dev/null | head -n 1 || true)"
main_debug_pid="$(pgrep -x MyLLMDebug 2>/dev/null | head -n 1 || true)"
main_watcher_pid="$(watcher_pid_for "$ROOT" 2>/dev/null || true)"
main_gridline_state="stopped"; [[ -z "$main_gridline_pid" ]] || main_gridline_state="running"
main_debug_state="stopped"; [[ -z "$main_debug_pid" ]] || main_debug_state="running"
main_watcher_state="stopped"; [[ -z "$main_watcher_pid" ]] || main_watcher_state="running"
printf '{"status":"stopped","target":"Gridline + Gridline Debug","time":"%s","gridline":"%s","gridlinePid":"%s","gridlineDebug":"%s","gridlineDebugPid":"%s","watcher":"%s","watcherPid":"%s"}\n' \
  "$timestamp" "$main_gridline_state" "$main_gridline_pid" "$main_debug_state" "$main_debug_pid" "$main_watcher_state" "$main_watcher_pid" \
  > "$ROOT/gridline_debug/build/latest-status.json"

echo "All Gridline apps and hot-reload watchers are stopped."
