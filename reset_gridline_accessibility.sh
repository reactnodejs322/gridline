#!/bin/zsh
set -u

ROOT="$(cd "$(dirname "$0")" && pwd)"
VERSIONS_DIR="$ROOT/gridline_versions"
typeset -a labels gridline_ids debug_ids gridline_pids debug_pids gridline_apps debug_apps

add_running_gridline() {
  local label="$1" gridline_id="$2" debug_id="$3" gridline_process="$4" debug_process="$5" gridline_app="$6" debug_app="$7"
  local gridline_pid debug_pid
  gridline_pid="$(pgrep -x "$gridline_process" 2>/dev/null | head -n 1 || true)"
  [[ -n "$gridline_pid" ]] || return
  debug_pid="$(pgrep -x "$debug_process" 2>/dev/null | head -n 1 || true)"
  labels+=("$label")
  gridline_ids+=("$gridline_id")
  debug_ids+=("$debug_id")
  gridline_pids+=("$gridline_pid")
  debug_pids+=("$debug_pid")
  gridline_apps+=("$gridline_app")
  debug_apps+=("$debug_app")
}

collect_running_gridlines() {
  add_running_gridline \
    "Gridline (main)" \
    "local.gridline.terminal" \
    "local.myllm.debuginspector" \
    "Gridline" \
    "MyLLMDebug" \
    "$ROOT/gridline/Gridline.app" \
    "$ROOT/gridline_debug/Gridline Debug.app"

  for version_path in "$VERSIONS_DIR"/version_*(N/); do
    local version_label number display_version
    version_label="${version_path:t}"
    number="${version_label#version_}"
    display_version="Version $number"
    add_running_gridline \
      "Gridline ($display_version)" \
      "local.gridline.terminal.version$number" \
      "local.myllm.debuginspector.version$number" \
      "Gridline$number" \
      "MyLLMDebug$number" \
      "$version_path/gridline/Gridline $display_version.app" \
      "$version_path/gridline_debug/Gridline Debug $display_version.app"
  done
}

show_running_gridlines() {
  print "Open Gridline instances"
  print "========================"
  if (( ${#labels[@]} == 0 )); then
    print "No Gridline app is running. Start the main app with ./start.sh or a saved version with ./start_versions.sh, then rerun this script."
    return 1
  fi
  local i debug_status
  for (( i = 1; i <= ${#labels[@]}; i++ )); do
    if [[ -n "${debug_pids[$i]}" ]]; then
      debug_status="Gridline Debug PID ${debug_pids[$i]}"
    else
      debug_status="Gridline Debug is not running"
    fi
    print -- "  $i) ${labels[$i]} — PID ${gridline_pids[$i]} — $debug_status"
  done
}

collect_running_gridlines
show_running_gridlines || exit 1

print ""
read -r "selection?Which Gridline are you working with? Enter its number: "
if [[ ! "$selection" == <-> ]] || (( selection < 1 || selection > ${#labels[@]} )); then
  print "That selection is not valid. No app permissions were changed."
  exit 2
fi

gridline_id="${gridline_ids[$selection]}"
debug_id="${debug_ids[$selection]}"
gridline_pid="${gridline_pids[$selection]}"
debug_pid="${debug_pids[$selection]}"
debug_app="${debug_apps[$selection]}"
label="${labels[$selection]}"
debug_process="MyLLMDebug"
[[ "$debug_id" == *.version<-> ]] && debug_process="MyLLMDebug${debug_id##*.version}"
gridline_process="Gridline"
[[ "$gridline_id" == *.version<-> ]] && gridline_process="Gridline${gridline_id##*.version}"
gridline_app="${gridline_apps[$selection]}"
gridline_pid_file="$(dirname "$debug_app")/build/gridline.pid"

print ""
print "Selected: $label (PID $gridline_pid)"
print "Its inspector is Gridline Debug ($debug_id)${debug_pid:+, currently PID $debug_pid}."
print "Accessibility access is required by Gridline Debug so it can inspect Gridline. macOS will not let this script enable it automatically."
print ""
print "Type RESET to clear both selected app permission records, close both apps, relaunch the pair, and open Accessibility settings."
print "Restarting Gridline will end its live terminal/Codex sessions. The script will verify both old processes exit and relink Debug to the new Gridline PID."
print "Enter Q to leave permissions unchanged."
read -r "confirmation?Confirm: "
if [[ "$confirmation" != "RESET" ]]; then
  print "No permissions were changed."
  exit 0
fi

osascript -e "tell application id \"$debug_id\" to quit" >/dev/null 2>&1 || true
osascript -e "tell application id \"$gridline_id\" to quit" >/dev/null 2>&1 || true
for attempt in {1..20}; do
  if ! pgrep -x "$debug_process" >/dev/null 2>&1 && ! pgrep -x "$gridline_process" >/dev/null 2>&1; then break; fi
  sleep 0.25
done
pkill -TERM -x "$debug_process" >/dev/null 2>&1 || true
pkill -TERM -x "$gridline_process" >/dev/null 2>&1 || true
for attempt in {1..20}; do
  if ! pgrep -x "$debug_process" >/dev/null 2>&1 && ! pgrep -x "$gridline_process" >/dev/null 2>&1; then break; fi
  sleep 0.25
done
if pgrep -x "$debug_process" >/dev/null 2>&1 || pgrep -x "$gridline_process" >/dev/null 2>&1; then
  print "Both old app processes did not exit cleanly. No replacement apps were opened."
  exit 1
fi

print "Resetting Accessibility permission for $gridline_id …"
gridline_reset_ok=1
tccutil reset Accessibility "$gridline_id" || gridline_reset_ok=0
print "Resetting Accessibility permission for $debug_id …"
debug_reset_ok=1
tccutil reset Accessibility "$debug_id" || debug_reset_ok=0
if (( ! gridline_reset_ok || ! debug_reset_ok )); then
  print "macOS could not reset one or both selected entries. The other Gridline versions were not touched."
  exit 1
fi

if [[ -d "$gridline_app" && -d "$debug_app" ]]; then
  open "$gridline_app"
  live_gridline_pid=""
  for attempt in {1..40}; do
    live_gridline_pid="$(pgrep -x "$gridline_process" 2>/dev/null | head -n 1 || true)"
    [[ -n "$live_gridline_pid" && "$live_gridline_pid" != "$gridline_pid" ]] && break
    sleep 0.25
  done
  if [[ -n "$live_gridline_pid" ]]; then
    printf '%s\n' "$live_gridline_pid" > "$gridline_pid_file"
    open "$debug_app"
    new_debug_pid=""
    for attempt in {1..40}; do
      new_debug_pid="$(pgrep -x "$debug_process" 2>/dev/null | head -n 1 || true)"
      [[ -n "$new_debug_pid" && "$new_debug_pid" != "$debug_pid" ]] && break
      sleep 0.25
    done
    if [[ -n "$new_debug_pid" ]]; then
      print "Closed both selected app processes and relaunched the pair. $label is PID $live_gridline_pid; Gridline Debug is PID $new_debug_pid."
    else
      print "Gridline relaunched as PID $live_gridline_pid, but its paired Gridline Debug did not relaunch."
      exit 1
    fi
  else
    print "Gridline did not relaunch with a new PID; Gridline Debug was not started with a stale target PID."
    exit 1
  fi
else
  print "Gridline or Gridline Debug app bundle not found for the selected copy."
  print "Gridline: $gridline_app"
  print "Gridline Debug: $debug_app"
fi
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" || true
print ""
print "In Accessibility settings, use + to add the selected Gridline Debug app and turn it on."
print "Only the selected app pair was reset and relaunched. Other Gridline versions were left running."
