# Hook vendors

## Ponytail

Source: `DietrichGebert/ponytail`. The first run of each copy's `start.sh` clones it into the ignored `.ponytail-upstream/` checkout when the prepared vendor is missing, then builds an ignored `ponytail/` snapshot. The pulled version and commit are in `ponytail/VENDOR_VERSION`.

Gridline's shared menu can pull upstream into an ignored checkout under `hook_vendor/` and refresh the prepared source. The prepared vendor is built from upstream, with a Gridline adaptation in `hooks/ponytail-map.js` that excludes `.codex/` from scanned source. Gridline uses the Ponytail skill instructions and codebase-map generator for its project-local Codex installer; its MIT license is preserved in `ponytail/LICENSE`.
