#!/bin/zsh
# Build, launch both native macOS apps, then rebuild and relaunch on Swift edits.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
exec "$ROOT/gridline_debug/watch-build.sh"
