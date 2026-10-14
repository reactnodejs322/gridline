#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GRIDLINE_APP="$ROOT/gridline/Gridline.app"
DEBUG_APP="$ROOT/gridline_debug/Gridline Debug.app"
GRIDLINE_ID="local.gridline.terminal"
REPORT="${TMPDIR:-/tmp}/gridline-usage-header-test-$$.txt"

if [[ ! -d "$GRIDLINE_APP" || ! -d "$DEBUG_APP" ]]; then
  print -u2 "Build the main Gridline and Gridline Debug apps first."
  exit 2
fi

reset_apps() {
  osascript -e "tell application id \"$GRIDLINE_ID\" to quit" >/dev/null 2>&1 || true
  osascript -e "tell application id \"local.myllm.debuginspector\" to quit" >/dev/null 2>&1 || true
  for attempt in {1..20}; do
    if ! pgrep -x Gridline >/dev/null && ! pgrep -x MyLLMDebug >/dev/null; then break; fi
    sleep 0.25
  done
  pkill -TERM -x Gridline >/dev/null 2>&1 || true
  pkill -TERM -x MyLLMDebug >/dev/null 2>&1 || true
  sleep 1
  open "$GRIDLINE_APP"
  open "$DEBUG_APP"
  for attempt in {1..40}; do
    if pgrep -x Gridline >/dev/null && pgrep -x MyLLMDebug >/dev/null; then
      sleep 3
      return 0
    fi
    sleep 0.25
  done
  print -u2 "Could not relaunch the Gridline app pair."
  return 1
}

cleanup() {
  print "Resetting Gridline and Gridline Debug after the test…"
  reset_apps || true
  unlink "$REPORT" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

print "Starting the test from a clean Gridline run…"
reset_apps
osascript -e "tell application id \"$GRIDLINE_ID\" to quit" >/dev/null 2>&1 || true
for attempt in {1..20}; do
  if ! pgrep -x Gridline >/dev/null; then break; fi
  sleep 0.25
done
print "Running Test 1 only through Gridline's own terminal PTY submission path…"
open -a "$GRIDLINE_APP" --args --terminal-usage-test "$REPORT"
PRINTED_LINES=0
for attempt in {1..50}; do
  if [[ -f "$REPORT" ]]; then
    LINE_COUNT="$(wc -l < "$REPORT" | tr -d ' ')"
    if (( LINE_COUNT > PRINTED_LINES )); then
      FIRST_NEW_LINE=$((PRINTED_LINES + 1))
      sed -n "${FIRST_NEW_LINE},${LINE_COUNT}p" "$REPORT"
      PRINTED_LINES="$LINE_COUNT"
    fi
    if rg -q '^RESULT (PASS|FAIL)$' "$REPORT"; then break; fi
  fi
  sleep 1
done
if [[ -f "$REPORT" ]] && rg -q '^RESULT PASS$' "$REPORT"; then
  TEST_EXIT=0
else
  print -u2 "Test runner timed out or reported a failure."
  TEST_EXIT=1
fi
print "\nFiltered Gridline Debug records for terminal 1ABC (shown before the app reset):"
python3 "$ROOT/tests/gridline_terminal_usage_test/print_test_logs.py" || true
exit "$TEST_EXIT"
