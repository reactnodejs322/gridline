# Project rules and copy selection

## Where this lives in code

- [start.sh](../start.sh)
- [start_versions.sh](../start_versions.sh)
- [Workspace.swift](../gridline/Sources/Gridline/Workspace.swift)
- [DebugEvents.swift](../gridline/Sources/Gridline/DebugEvents.swift)

## Copy selection and isolation

Choose the requested app copy before editing.
Main and versioned copies have separate app identities and runtime data.

| Target | Source roots | Start or debug |
| --- | --- | --- |
| Main | `gridline/`, `gridline_debug/` | Run `./start.sh`. |
| Version 1 | `gridline_versions/version_1/` | Select Version 1 in `./start_versions.sh`. |
| Version N | `gridline_versions/version_N/` | Select it in `./start_versions.sh`. |

- Do not edit root `gridline/` for a Version 1 request.
- Do not copy changes between app copies unless requested.
- Each version has its own IDs, workspace data, and debug event log.
- Keep version-specific values scoped to that version.
- Root `README.md` is the human overview; versions may have their own `AGENTS.md`.
## Project layout

- gridline/ contains the main native macOS app, Swift package, app build scripts, and app-specific notes.
- gridline_debug/ contains the companion inspector, its Swift package, INDEX.md, behavior logs, reports, and build diagnostics.
- gridline_research/ contains product and repository research, including comparisons with other terminal projects.
- `gridline/usage/` contains Gridline's bundled, reusable provider usage readers and estimates; keep any external reference implementation copied here before integration.
- `hook_vendor/ponytail/` is an ignored prepared copy of the upstream Ponytail source and license. Each copy's `start.sh` runs `gridline/hooks/update_ponytail_vendor.py ensure` before building, cloning upstream only when the prepared source is missing. The map helper has one Gridline adaptation that excludes `.codex/`; provider-specific Gridline hook adapters live in `gridline/hooks/`.
- `gridline/runtime/gridline_trace.py` is the shared safe Python stage logger; `DebugEvents.configurePythonProcess` in `gridline/Sources/Gridline/DebugEvents.swift` bridges its records into Gridline Debug. Use `recordExternalProcess` for Swift-launched native commands such as `ps` so they are not mislabeled as Python scripts.
- `skill_script/` contains selectable local-processing skills and their setup script.
- logo/Gridline2x.png is the shared editable logo source. The inspector build generates its bug-badge variant from this file.
- The root contains README.md, this AGENTS.md, start.sh, start_versions.sh, and stop.sh.
- SwiftPM checkouts and build products are in `.build/` and ignored by Git.
- Commit `Package.swift` and `Package.resolved`, not `.build/`.
## Implementation rules

- Keep all skill models under `skill_script/resources/models/`.
- Never commit model binaries.
- Keep pinned model URLs and SHA-256 values in `skill_script/download_models.py`.
- Document new model paths in `skill_script/README.md` and [`skills-and-models.md`](skills-and-models.md).
- Git ignore and version-copy rules cover model binaries for every skill.
- Read `gridline_debug/INDEX.md` before changing app behavior.
- Reuse existing views, styles, functions, and helpers.
- Keep Gridline code in `gridline/` and inspector code in `gridline_debug/`.
- Put cross-app build coordination in root launchers or the watcher.
- Preserve stable Accessibility identifiers and semantic events.
- Never log terminal output, individual keystrokes, credentials, or arbitrary control values. While the paired Gridline Debug inspector is open, terminal targeting, completed Enter submissions, and per-terminal usage diagnostics may include the saved workgroup name beside its UUID. The `terminal.inputSubmitted` event in `events.jsonl` keeps only character counts; by the user's explicit request, a completed Codex prompt is written separately to the local, Git-ignored `gridline_debug/timeline.jsonl` with the same submission ID. Never put prompt text in `events.jsonl`, inspector reports, or terminal-derived titles.
- Keep implementation guidance in `docs/` and user-facing copy in `README.md`.
- If a user points to a script or implementation outside this repository, treat it as reference material and copy the needed logic into `gridline/` before integrating it. Do not edit the outside source unless explicitly asked.

## Checkpoint

- [x] The original AGENTS.md guidance in the sections above is preserved here.
- [ ] Recheck paths and behavior when the owning implementation changes.
