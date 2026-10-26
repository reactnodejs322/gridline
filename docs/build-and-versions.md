# Build and version lifecycle

## Where this lives in code

- [start.sh](../start.sh)
- [start_versions.sh](../start_versions.sh)
- [stop.sh](../stop.sh)
- [build-app.sh](../gridline/build-app.sh)
- [watch-build.sh](../gridline_debug/watch-build.sh)

## Start the main app

- Run `./start.sh` from the repository root.
- It prepares Ponytail in the ignored `hook_vendor/ponytail/` folder if needed, then starts `gridline_debug/watch-build.sh` in the foreground.
- The watcher downloads missing model resources, then builds Gridline and Gridline Debug.
- After a successful build, it opens one matching app pair and watches source changes.
- Changes to Swift code or skill scripts rebuild and relaunch the pair.
- A successful rebuild ends that copy's live terminal sessions.
- Keep the launcher terminal open; press Ctrl-C to stop the watcher.
- Diagnostics are written to `gridline_debug/build/`.
- Do not start a second watcher when the main pair is already running.
## Gridline version lifecycle

`./start_versions.sh` manages isolated copies under `gridline_versions/`.
Each copy has its own `VERSION`, app bundle IDs, workspace data, logs, and watcher.

### Create a version

- Choose **Create** in `./start_versions.sh`.
- The script chooses the first unused `version_N` folder.
- It copies Gridline, Gridline Debug, the logo, and skill-script sources.
- It leaves Ponytail out of the version copy; that version's `start.sh` clones its own ignored Ponytail source when first started.
- It skips build products, app bundles, debug logs, and model binaries.
- It writes that version's `VERSION`, `README.md`, and `AGENTS.md` files.
- It starts the new copy and downloads missing models into its own `skill_script/resources/models/`.
- The version's build scripts use its `VERSION` to set unique app names and bundle IDs.

### Debug an existing version

- Choose **Debug** and select a listed version.
- The manager starts that version's own `start.sh` and hot-reload watcher.
- Press Ctrl-C to stop its watcher; use **Stop** to close its apps too.
- The manager shows whether its apps and watcher are running.

### Stop a version

- Choose **Stop** and select the version.
- The manager stops its watcher before closing that version's app pair.
- Source files and version-specific saved data remain in its folder.
## Shared stop and diagnostic commands

- `./stop.sh` stops the main app pair and all numbered versions.
- Each watcher writes its app PID and build diagnostics inside that copy's `gridline_debug/build/`. The main watcher runs `gridline_debug/collect_debug_logs.py`, which copies build results and semantic events into local `gridline_debug/timeline.jsonl`; Gridline appends completed Codex prompts there while Gridline Debug is open. The timeline resets on Gridline app launch; the Debug log viewer's Reset logs button requests deletion of the timeline, raw events, and saved build diagnostics. Inspect logs through the full-width lower viewer or `./gridline_debug/inspect-logs.sh`. The root `hot-reload-logs.md` remains a read-only archive. Generated logs and `user-log-view.json` are ignored by Git.
- `gridline_versions/runtime-status.json` summarizes version app and watcher state.
- A failed build leaves the current apps open and records errors in that copy's build folder.

## Checkpoint

- [x] The original AGENTS.md guidance in the sections above is preserved here.
- [ ] Recheck paths and behavior when the owning implementation changes.
