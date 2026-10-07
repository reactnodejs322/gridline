# Coding Agent Guide

Start with this map, then open one relevant index or source file.
This guide is the technical handoff; README.md is for people exploring Gridline.

## Table of Contents

| Chapter | Section | What to find |
| --- | --- | --- |
| 1 | [Skill scripts and model resources](#skill-scripts-and-model-resources) | Skills, shared models, and downloads |
| 1.1 | [Audio to text](#audio-to-text) | File transcription and speaker labels |
| 1.2 | [Voice todo](#voice-todo) | Live voice capture and Problem Notes |
| 1.3 | [Model locations and downloads](#model-locations-and-downloads) | Model paths, pins, and checksums |
| 2 | [Search the code](#grep-guide) | `rg` commands and search scope |
| 3 | [Choose the app copy](#copy-selection-and-isolation) | Main Gridline or isolated version |
| 4 | [Project layout](#project-layout) | Repository folders and responsibilities |
| 5 | [Implementation rules](#implementation-rules) | Shared UI, model, and logging rules |
| 6 | [Current product behavior](#current-product-and-behavior-context) | Shipped Gridline behavior |
| 7 | [Source map and identifiers](#source-map-and-stable-identifiers) | Swift files and Accessibility IDs |
| 8 | [Start the main app](#start-the-main-app) | Build, launch, and hot reload |
| 9 | [Gridline version lifecycle](#gridline-version-lifecycle) | Create, debug, and stop isolated copies |
| 9.1 | [Create a version](#create-a-version) | Copy sources and download local models |
| 9.2 | [Debug an existing version](#debug-an-existing-version) | Start one selected version |
| 9.3 | [Stop a version](#stop-a-version) | Stop its watcher and app pair |
| 10 | [Shared stop and diagnostic commands](#shared-stop-and-diagnostic-commands) | Stop copies and locate build reports |
| 11 | [Inspector permissions and diagnostics](#inspector-permissions-and-diagnostic-data) | Accessibility, logs, and reports |
| 12 | [Product direction](#product-direction-and-handoff) | Future ideas and handoff guidance |

## Skill scripts and model resources

### Audio to text

- Skill folder: `skill_script/audio_to_text/`.
- Produces transcripts from selected audio or video files.
- Uses Whisper and, when enabled, speaker diarization.

### Voice todo

- Skill folder: `skill_script/voice_todo/`.
- Uses the shared Whisper model for live voice capture.
- Writes recognized speech into editable Problem Notes.

### Model locations and downloads

- Whisper folder: `skill_script/resources/models/whisper-small-mlx/`.
- Whisper weights: `skill_script/resources/models/whisper-small-mlx/weights.npz`.
- Speaker segmentation: `skill_script/resources/models/speaker-diarization/segmentation/model.onnx`.
- Speaker embeddings: `skill_script/resources/models/speaker-diarization/speaker-embedding/model.onnx`.
- Downloader: `skill_script/download_models.py`.
- Model binaries are ignored by Git; the downloader pins revisions and verifies SHA-256.
- Builds and new version copies download missing models into their own resource folder.

## Grep guide

Use `rg` to find a topic before opening a large source file.

~~~sh
# Browse this guide, the compact UI index, and research headings.
rg -n '^#{1,3} ' AGENTS.md gridline_debug/INDEX.md gridline_research/REPOSITORY_RESEARCH.md

# Find main app behavior, visible labels, or stable Accessibility identifiers.
rg -n -i 'work group|codex|collapse|folder|sidebar|directory command|terminal title|gridline\.' \
  gridline/Sources gridline_debug/Inspector/Sources

# Find a behavior in a numbered snapshot; replace version_1 if needed.
rg -n -i 'FEATURE OR CONTROL WORDS' \
  gridline_versions/version_1/gridline_debug/INDEX.md \
  gridline_versions/version_1/gridline/Sources \
  gridline_versions/version_1/gridline_debug/Inspector/Sources

# Find launcher, pairing, or permission behavior.
rg -n 'watch-build|GridlineTargetBundleID|GridlineTargetPIDFile|gridline\.pid|Accessibility' \
  start.sh start_versions.sh stop.sh gridline_debug gridline_versions
~~~

- Main app changes: search `gridline/` and `gridline_debug/`.
- Version changes: search only the selected version's app trees.
- Replace `FEATURE OR CONTROL WORDS` with terms from the request.
- Open the relevant source after locating it; avoid broad file dumps.

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
- `skill_script/` contains selectable local-processing skills and their setup script.
- logo/Gridline2x.png is the shared editable logo source. The inspector build generates its bug-badge variant from this file.
- The root contains README.md, this AGENTS.md, start.sh, start_versions.sh, and stop.sh.
- SwiftPM checkouts and build products are in `.build/` and ignored by Git.
- Commit `Package.swift` and `Package.resolved`, not `.build/`.

## Implementation rules

- Keep all skill models under `skill_script/resources/models/`.
- Never commit model binaries.
- Keep pinned model URLs and SHA-256 values in `skill_script/download_models.py`.
- Document new model paths in `skill_script/README.md` and this map.
- Git ignore and version-copy rules cover model binaries for every skill.
- Read `gridline_debug/INDEX.md` before changing app behavior.
- Reuse existing views, styles, functions, and helpers.
- Keep Gridline code in `gridline/` and inspector code in `gridline_debug/`.
- Put cross-app build coordination in root launchers or the watcher.
- Preserve stable Accessibility identifiers and semantic events.
- Never log terminal text, keystrokes, credentials, or control values.
- Keep implementation guidance here and user-facing copy in `README.md`.

## Current product and behavior context

- Gridline is a native macOS workspace for organizing parallel Codex CLI work. A named work group represents a task or project, keeps its project folder visible, and can be collapsed or selected from the sidebar.
- The current UI starts one Codex terminal in an empty work group. Do not describe multiple terminals per group or user-created shell sessions as current UI behavior unless the implementation changes.
- The workspace has one, two, or three group columns. It saves group names, folders, collapse state, terminal labels, per-terminal font size and height, and layout metadata in ~/Library/Application Support/Gridline/workspace.json (numbered copies scope their saved data to their version). Terminals start at 10 pt and can zoom down to 6 pt; their pane heights resize independently.
- Saved workspace metadata is not a saved process. Quitting or rebuilding ends live shell/Codex PTYs; reopening creates fresh terminal processes.
- Session labels begin with a short label such as Codex. A terminal title event may update an automatic label. A user-edited label takes precedence. Do not infer a task title when the CLI has not sent one.
- The workspace directory prompt supports its documented cd, pwd, and ls interactions, folder completion, and folder navigation. It validates paths and does not execute arbitrary shell commands. New groups and sessions use the saved default folder.
- Gridline Debug is a separate native app. Its listen-only pointer monitor examines Accessibility elements from the paired Gridline process. Hover previews and outlines an element; clicking pins it and records a selection.
- The inspector combines selected Accessibility metadata with Gridline's semantic event log at gridline_debug/events.jsonl. Copy LLM context includes the element, likely source path, an rg command, and relevant nearby events. It does not store terminal text, control values, credentials, or screenshots in reports.
- Gridline's UI, data model, and workflow are original to this project. gridline_research/REPOSITORY_RESEARCH.md is a working reference for product and code research. Learn a focused idea; do not copy another app's screen, branding, source, or internal protocols.

## Source map and stable identifiers

The compact, maintained mapping from identifiers to likely implementation files is gridline_debug/INDEX.md. Start there. Main paths include:

- Grid, group cards, toolbar, directory prompt, and terminal sessions: gridline/Sources/Gridline/Workspace.swift.
- Semantic app event schema and path: gridline/Sources/Gridline/DebugEvents.swift.
- Inspector selection, hover, copy, and reports: gridline_debug/Inspector/Sources/MyLLMDebug/InspectorStore.swift and InspectorView.swift.
- Accessibility hit-test fields: gridline_debug/Inspector/Sources/MyLLMDebug/DebugElement.swift.
- Accessibility identifier to likely Swift action/event map and copied context: gridline_debug/Inspector/Sources/MyLLMDebug/GridlineCodeContext.swift.
- Non-interactive hover border overlay: gridline_debug/Inspector/Sources/MyLLMDebug/HoverHighlight.swift.
- App/package build: gridline/build-app.sh; rebuild-on-change watcher: gridline_debug/watch-build.sh.

Stable identifiers include gridline.group.new, gridline.session.newCodex, gridline.workspace.directoryCommand, gridline.workspace.groupSidebar, gridline.group.toggle.<UUID>, gridline.group.close.<UUID>, gridline.group.name.<UUID>, gridline.group.addCodex.<UUID>, gridline.group.folder.<UUID>, gridline.session.label.<UUID>, gridline.session.close.<UUID>, gridline.session.terminal.<UUID>, and gridline.layout.columns. Search identifiers or visible titles with rg 'gridline\.|visible title' gridline/Sources gridline_debug.

Per-terminal controls also use `gridline.session.zoomOut.<UUID>`, `gridline.session.zoomIn.<UUID>`, `gridline.session.fontSize.<UUID>`, and `gridline.session.resizeHeight.<UUID>`.

## Start the main app

- Run `./start.sh` from the repository root.
- It starts `gridline_debug/watch-build.sh` in the foreground.
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
- Each watcher writes its app PID and build diagnostics inside that copy's `gridline_debug/build/`.
- `gridline_versions/runtime-status.json` summarizes version app and watcher state.
- A failed build leaves the current apps open and records errors in that copy's build folder.

## Inspector permissions and diagnostic data

- If Gridline Debug reports Accessibility permission needed, use Set up access… and enable the matching app in macOS Accessibility settings: gridline_debug/Gridline Debug.app for main, or the paired version's inspector app.
- If Accessibility is active but pointer monitoring is unavailable, check Privacy & Security → Input Monitoring and restart the matching inspector.
- Use ./reset_gridline_accessibility.sh to list or reset only Gridline app permission entries. Preserve its explicit confirmation; never reset the global Accessibility service. Resetting closes and relaunches the selected app pair and ends its terminal sessions.
- gridline_debug/events.jsonl contains semantic UI actions and terminal lifecycle events, not terminal output. gridline_debug/build/latest-status.json is the last build result; latest-errors.txt is the compact diagnostic; latest.log is full compiler output. Reports live under gridline_debug/reports/; .gitignore keeps generated reports and build diagnostics out of Git.
- AX inspection only covers elements exposed in the target app's Accessibility tree. The hierarchy does not promise exact Swift source line numbers. Use the index and code-context mapping rather than guessing.

## Product direction and handoff

Current product priorities are a clearer project-first terminal grid, reliable group and session labels, saved organizational context, and trustworthy session state. Potential follow-up work includes resizable grid proportions, a focused/maximized terminal, session state cues based on reliable signals, restored ordering/selection, and a supported Codex title hook or app-server event. Treat these as direction, not shipped features.

For a focused behavior change, read the relevant section in gridline_debug/INDEX.md, search the mapped source, then open only that file. For Version 1 requests, confirm the target copy and use its matching source, index, and watcher. After implementation, keep gridline_debug/INDEX.md accurate and update this guide only when durable project context changes.
