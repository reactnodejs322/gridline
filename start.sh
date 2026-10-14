#!/bin/zsh
# Build, launch both native macOS apps, then rebuild and relaunch on Swift edits.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
if ! python3 -B "$ROOT/gridline/hooks/update_ponytail_vendor.py" ensure --repo-root "$ROOT"; then
  echo "Could not prepare Ponytail. Check Git access and retry ./start.sh." >&2
  exit 1
fi
exec "$ROOT/gridline_debug/watch-build.sh"
