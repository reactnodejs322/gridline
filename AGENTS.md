# Project instructions for coding agents

## Project layout

- `gridline/` contains the Gridline macOS app, its Swift package, build scripts, and app research docs.
- `gridline_debug/` contains the companion inspector app, its Swift package, UI context index, behavior logs, reports, and build diagnostics.
- `logo/Gridline2x.png` is the single editable logo source shared by both apps. The inspector build generates its bug-badge variant from this file.
- The root contains project-level documentation, `start.sh` for the main copy, and `start_versions.sh` for isolated version snapshots.
- Gridline Debug reads `GridlineTargetBundleID` and `GridlineTargetPIDFile`; keep both values paired with the same app copy. It resolves the sole live process for that bundle ID, refreshes that copy's `gridline.pid`, and refuses to inspect if the match is ambiguous.
- Use `./reset_gridline_accessibility.sh` to list or reset only Gridline app permissions; keep the explicit confirmation and never reset the global Accessibility service.
- A version snapshot has a root `VERSION` file. Keep its Gridline bundle ID, inspector target bundle ID, workspace data, and debug event log scoped to that version.

## Implementation rules

- Before editing, read `gridline_debug/INDEX.md` for the compact map from UI behavior and Accessibility identifiers to source files.
- Reuse existing functions, views, styles, and shared helpers. Extend an existing implementation when possible; do not create duplicate code or parallel styling systems for the same behavior.
- Keep Gridline implementation in `gridline/` and inspector implementation in `gridline_debug/`. Put cross-app launch/build coordination in the root launcher or `gridline_debug/watch-build.sh`.
- Keep the apps native SwiftUI/AppKit and preserve stable Accessibility identifiers and meaningful semantic events.
- Never write terminal output, control values, credentials, or API keys to inspector logs or reports.
- Keep README and index paths aligned with the current folder structure.

## Build and launch

Run `./start.sh` from the project root to build and open one instance of each app, then watch Swift sources for changes. Successful rebuilds restart both apps and end active terminal sessions. Save terminal work before changing Swift files while the watcher is running. Build diagnostics are written to `gridline_debug/build/`.
