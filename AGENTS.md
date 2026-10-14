# Coding Agent Guide

> **PLEASE RESIST ON CHANGING UP MY BOOK LIKE TABLE OF CONTENT.** Keep this single linked chapter map intact; only update it when a chapter or destination changes.

Start with this map, then open one relevant index or source file.
This guide is the technical handoff; README.md is for people exploring Gridline.

## Quick reference: inspect the logs currently shown in Gridline Debug

When the user asks you to look at their Gridline logs, run this from the repository root:

~~~sh
./gridline_debug/inspect-logs.sh showUserlogFilters --format llm
~~~

This reads Gridline Debug's live **Show**, **Workgroup**, and **Search** selections from `gridline_debug/user-log-view.json`, then prints matching timeline rows as structured JSON, including recorded details and each Swift/Python code-path step expanded to its repo-relative file location. The Debug app refreshes that state when a filter changes or the timeline updates, so this command follows the user's current view instead of assuming `--category all`. It also reports whether the Debug window is open and whether **Following** is on. By default it prints the latest 30 matching rows; append `--limit 0` to print every match. Use `--format text` for compact log lines with readable code paths.

When the user asks to see the full latest log output, run `./gridline_debug/inspect-logs.sh showUserlogFilters --format text --limit N` (for example, `--limit 50`) and paste the complete command output without summarizing it. `--limit` counts matching log entries, not physical display lines; the command returns fewer if fewer entries match. Use `--format llm` when structured JSON is useful for analysis. See [Inspector permissions and diagnostic data](#inspector-permissions-and-diagnostic-data) for details and independent-filter commands.

## Table of Contents

| Chapter | Section | What to find |
| --- | --- | --- |
| 1 | [Skill scripts and model resources](#skill-scripts-and-model-resources) | Skills, shared models, and downloads |
| 1.1 | [Audio to text](#audio-to-text) | File transcription and speaker labels |
| 1.2 | [Voice todo](#voice-todo) | Live voice capture and Problem Notes |
| 1.3 | [Model locations and downloads](#model-locations-and-downloads) | Model paths, pins, and checksums |
| 2 | [Search the code](#find-a-source-file) | File map and ready-to-run `rg` searches |
| 3 | [Choose the app copy](#copy-selection-and-isolation) | Main Gridline or isolated version |
| 4 | [Project layout](#project-layout) | Repository folders and responsibilities |
| 5 | [Implementation rules](#implementation-rules) | Shared UI, model, and logging rules |
| 5.1 | [UI templates and skins](#ui-templates-and-skins) | Add visual templates without duplicating workflows |
| 5.2 | [Template architecture guide](gridline/template/README.md) | Where skins live, how they render, and how to add one |
| 5.3 | [Main template guide](gridline/template/main_template/README.md) | The default skin's components and shared label-data path |
| 5.4 | [Reusable logic and bundled tools](#reusable-logic-and-bundled-tools) | Keep provider data logic inside Gridline and separate from template UI |
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
| 13 | [Swift code hygiene and LLM navigation](#swift-code-hygiene-and-llm-navigation) | Swift conventions, focused file discovery, and audit notes |

## Find a source file

Run these commands from the repository root on macOS, Linux, or Windows. `rg` (ripgrep) works across those platforms; use the exact search terms below, then open the matching file instead of dumping whole folders.

| Looking for… | Search command | Likely file |
| --- | --- | --- |
| Template types, catalog, selection persistence | `rg -n 'GridlineTemplate|GridlineTemplateCatalog|GridlineTemplateStore|GridlineWorkGroupCardContext' gridline/template` | `gridline/template/TemplateCatalog.swift` |
| Main template definition and view components | `rg -n 'MainTemplate|groupHeader|TerminalPane|zoomOut|resizeTerminal' gridline/template/main_template` | `gridline/template/main_template/` |
| Reusable template dropdown panel and action rows | `rg -n 'MainTemplateDropdownPanel|MainTemplateDropdownActionRow' gridline/template gridline/Sources/Gridline` | `gridline/template/main_template/MainTemplateDropdownPanel.swift`, `gridline/template/main_template/MainTemplateDropdownActionRow.swift` |
| Where the selected skin enters the workspace | `rg -n 'activeTemplate|makeWorkGroupCard|gridline\.template\.active' gridline/Sources/Gridline/Workspace.swift` | `gridline/Sources/Gridline/Workspace.swift` |
| Template Accessibility IDs and inspector mapping | `rg -n 'gridline\.(template|group|session)\.' gridline/template gridline_debug/INDEX.md gridline_debug/Inspector/Sources/MyLLMDebug/GridlineCodeContext.swift` | Template Swift views and `gridline_debug/` |
| Template source inclusion and live reload | `rg -n 'template/|main_template' gridline/Package.swift gridline_debug/watch-build.sh` | `gridline/Package.swift`, `gridline_debug/watch-build.sh` |
| Provider usage readers, estimates, per-terminal snapshots, and terminal detection | `rg -n 'ProviderUsageStatus|TerminalUsageStatus|TerminalUsageSnapshot|terminal_usage|detectProviders' gridline/Sources/Gridline/ProviderUsageService.swift gridline/usage` | `gridline/Sources/Gridline/ProviderUsageService.swift`, `gridline/usage/` |
| Codex project hooks, live terminal folder, Ponytail installer | `rg -n 'CodexHooksPanel|install_project_hooks|PreCompact|PostCompact|currentDirectory' gridline/Sources/Gridline gridline/hooks` | `gridline/Sources/Gridline/CodexHooks.swift`, `gridline/hooks/`, `hook_vendor/ponytail/` |
| Shared Ponytail source update | `rg -n 'PonytailVendorUpdate|update_ponytail_vendor|ponytailSource' gridline/Sources/Gridline gridline/hooks gridline/template` | `Workspace.swift`, `CodexHooks.swift`, `gridline/hooks/update_ponytail_vendor.py`, `hook_vendor/ponytail/VENDOR_VERSION` |
| Provider usage status presentation | `rg -n 'MainTemplateUsageStatusView|makeUsageStatusView|gridline.workspace.tokenUsage' gridline/template gridline/Sources/Gridline/Workspace.swift` | `gridline/template/main_template/MainTemplateUsageStatusView.swift` |
| Terminal labels, zoom, resizing, and saved state | `rg -n 'func rename|func zoom|resizeTerminal|workspace\.json|class TerminalSession' gridline/Sources/Gridline/Workspace.swift` | `gridline/Sources/Gridline/Workspace.swift` |
| A control or workflow in the main app | `rg -n -i 'SEARCH WORDS|gridline\.identifier' gridline/Sources/Gridline gridline_debug/INDEX.md` | Start with the match, then inspect its containing Swift file |
| A feature in an isolated app version | `rg -n -i 'SEARCH WORDS|gridline\.identifier' gridline_versions/version_N/gridline gridline_versions/version_N/gridline_debug` | Replace `version_N` with the selected version |

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
- Document new model paths in `skill_script/README.md` and this map.
- Git ignore and version-copy rules cover model binaries for every skill.
- Read `gridline_debug/INDEX.md` before changing app behavior.
- Reuse existing views, styles, functions, and helpers.
- Keep Gridline code in `gridline/` and inspector code in `gridline_debug/`.
- Put cross-app build coordination in root launchers or the watcher.
- Preserve stable Accessibility identifiers and semantic events.
- Never log terminal output, individual keystrokes, credentials, or arbitrary control values. While the paired Gridline Debug inspector is open, terminal targeting, completed Enter submissions, and per-terminal usage diagnostics may include the saved workgroup name beside its UUID. The `terminal.inputSubmitted` event in `events.jsonl` keeps only character counts; by the user's explicit request, a completed Codex prompt is written separately to the local, Git-ignored `gridline_debug/timeline.jsonl` with the same submission ID. Never put prompt text in `events.jsonl`, inspector reports, or terminal-derived titles.
- Keep implementation guidance here and user-facing copy in `README.md`.
- If a user points to a script or implementation outside this repository, treat it as reference material and copy the needed logic into `gridline/` before integrating it. Do not edit the outside source unless explicitly asked.

## UI templates and skins

- Template source code and skin folders: `gridline/template/`. `gridline/Package.swift` explicitly includes each template Swift file in the Gridline app target; `gridline_debug/watch-build.sh` watches this folder for reloads.
- Skin-specific assets and notes: `gridline/template/<template_id>/`; current skin: `gridline/template/main_template/`.
- `main_template` is the default skin and preserves the current Gridline appearance.
- A template owns its SwiftUI presentation components: palette, layout, spacing, labels, and controls. Shared data and actions remain in Gridline models/stores; template controls call those shared paths rather than keeping separate copies.
- Put reusable presentation components beside the skin that owns their appearance, in `gridline/template/<template_id>/`; no extra component folder is needed unless a template grows enough components to warrant one. For the main skin, `gridline/template/main_template/MainTemplateDropdownPanel.swift` is the shared palette-aware dropdown surface and `MainTemplateDropdownActionRow.swift` is its matching action row. Use these for new dropdown/popover panels and action items so their title, border, surface, hover state, spacing, and shadow stay consistent. Search with `rg -n 'MainTemplateDropdownPanel|MainTemplateDropdownActionRow' gridline/template gridline/Sources/Gridline` before creating another dropdown style.
- `GridlineTemplate.makeWorkGroupCard` selects each skin's card component; `makeUsageStatusView` selects its status presentation. Both receive shared models/snapshots rather than owning duplicate data.
- Terminal labels are per-session data in `SavedSession` and persist to `~/Library/Application Support/Gridline/workspace.json`. Every template must edit them through `TerminalSession.rename(_:)`, which saves through `WorkspaceStore.changed()`.
- The template owns UI components, including how each terminal label is presented and edited. Gridline's shared `TerminalSession` and `WorkspaceStore` own the label value, terminal-title behavior, and persistence; never create a template-local copy of terminal data.
- The selected template ID is persisted in UserDefaults. Add future selectable skins to `GridlineTemplateCatalog`; build the template dropdown from that catalog instead of hardcoding menu items.
- Add a distinct template view/composition only when a skin needs a different arrangement or additional presentation. Pass shared feature actions and state into it so existing workflows remain consistent.
- Keep stable Accessibility identifiers attached to shared controls even when a template changes their visual presentation.
- Make each rendered template root an Accessibility container labeled with its template ID and identified as `gridline.template.active.<template_id>`. Give each interactive template control its own stable identifier; do not make the root identifier replace child control IDs.
- Template selector controls use `gridline.template.selector` and `gridline.template.option.<template_id>`. Record `template.selected` with the option identifier so Gridline Debug can correlate a selection.

### Main template dropdown code flow

Use this path when changing a dropdown's appearance, open/close behavior, or actions. `MainTemplateDropdownPanel` and `MainTemplateDropdownActionRow` are presentation components; they do not own workspace or provider state.

| UI / entry point | State and reusable view | Action destination |
| --- | --- | --- |
| Workspace hamburger | [`WorkspaceView.topBar`](gridline/Sources/Gridline/Workspace.swift) owns `isWorkspaceActionsExpanded`; it presents `MainTemplateDropdownPanel` with shared action rows. | Rows call `WorkspaceStore`, change the selected app tab, or open the directory/skill-script panel. Grid column changes go through `WorkspaceStore.setColumns(_:)`. |
| Skill scripts | `WorkspaceView.topBar` opens `SkillScriptDropdownView` in `Workspace.swift`; that view uses the shared panel and action rows with the active template palette. | Closures launch audio transcription or open Voice todo; implementations remain in their existing skill/workspace paths. |
| Work-group ellipsis | [`MainTemplateWorkGroupCard`](gridline/template/main_template/MainTemplateWorkGroupCard.swift) owns `showingActionsDropdown` and presents the shared panel. | Folder, group, and session actions call `WorkspaceStore` or `TerminalSession`; retain their existing Accessibility IDs. |
| ChatGPT usage meter | [`MainTemplateUsageStatusView`](gridline/template/main_template/MainTemplateUsageStatusView.swift) keeps the meter visible and opens the shared panel for refresh preferences. | Bindings call `CodexUsageStatus`; the usage monitor and saved settings live in [`ProviderUsageService.swift`](gridline/Sources/Gridline/ProviderUsageService.swift). |
| Directory command | `WorkspaceView.directoryCommandPopover` uses the shared panel around the existing inline `cd`/`pwd`/`ls` field. | `WorkspaceView.runDirectoryCommand()` delegates to `WorkspaceStore`; preserve its validation and completion behavior. |

To trace a new dropdown, start at its trigger and `@State` in the table, follow its `.popover` to the shared panel, then follow each action closure to the named store/service. Do not move action logic into the reusable panel or duplicate state there.

## Reusable logic and bundled tools

- Keep provider data collection and calculations separate from SwiftUI. Reusable service/state types belong in `gridline/Sources/Gridline/`; local Python readers and calculators belong in `gridline/usage/`.
- Python usage tools emit machine-readable JSON and read provider usage metadata only. They must not read or retain prompts, terminal output, keystrokes, or credentials.
- Per-terminal usage snapshots retain the last confirmed counts through temporary pending, ambiguous, unavailable, or no-provider polls. Clear that cached display only when the Gridline terminal process identity changes or the session is removed; keep reader status diagnostics visible while retaining.
- Pricing maintenance instructions and official rate-card links are in `gridline/usage/README.md`. Rate maps are local snapshots, not live page scrapes; a coding LLM must verify current official rates before changing them and leave unknown model rates unpriced.
- The top status has two weekly meters. ChatGPT uses the monitor's reported seven-day plan allowance; the dollar display is that percentage of the stated $20 plan price. Its header dropdown controls a persistent allowance-monitor process, defaults to a three-second interval, supports intervals from one second to sixty minutes, and can disable continuous fetching while retaining the last snapshot. Claude uses a rolling seven-day API-equivalent estimate from assistant token metadata, compared with a $20 reference. Neither amount is a subscription charge; never substitute Claude's lifetime aggregate cost for its weekly estimate.
- Bundle `gridline/usage/` into the Gridline app in `gridline/build-app.sh` and include it in the hot-reload fingerprint in `gridline_debug/watch-build.sh`.
- Bundle `gridline/hooks/` and the small Ponytail resources needed at runtime in `gridline/build-app.sh`; include them in the watcher fingerprint. The Codex project installer writes under the live terminal's Git root (or its live folder outside Git), merges `.codex/hooks.json`, and preserves an existing `.codex/ponytail.md`.
- Bundle `gridline/runtime/` beside the usage tools in the app resources and include it in the watcher fingerprint. New Swift-launched Python work should use `DebugEvents.configurePythonProcess`; Python scripts emit named stages through `gridline/runtime/gridline_trace.py`.
- Swift services call the bundled tools, normalize output into typed snapshots, and own refresh timing and process-name detection. Keep provider parsing, price math, and process scanning out of `WorkspaceView` and template views.
- Per-terminal usage is separate from the weekly header meter. `TerminalUsageStatus` streams `gridline/usage/terminal_usage.py` snapshots every three seconds; the script matches active CLI processes to provider session files. UI focus never assigns usage. When candidates are shared, a completed Enter submission can pin a file only if that file updates after the submission and no competing terminal submits before the update; otherwise leave it ambiguous. The reader receives only a terminal ID and timestamp, never submitted text or character content. With Gridline Debug open, `workspace.terminalUsageSubmissionForwarded` confirms the Swift-to-Python handoff and `workspace.terminalUsageStatusChanged` reports the reader's submission resolution. The single `gridline.workspace.terminalUsage.disable` checkbox pauses this local watcher for all terminals, preserves in-memory snapshots, and hides the per-terminal IN/OUT rows across all workgroups. The custom interval only controls weekly allowance polling.
- Debug-only diagnostics are written only while the matching Gridline Debug app is open. This includes `terminal.targeted` and `terminal.inputSubmitted` (session/workgroup UUID, saved workgroup name, and terminal kind) plus per-terminal usage status and reader failure events (`workspace.terminalUsageStatusChanged`, `workspace.terminalUsageMonitorFailed`). Enter events count inserted and pasted characters separately, not PTY bytes or terminal control traffic; they never store the text in `events.jsonl`. The ignored `gridline_debug/timeline.jsonl` is the one explicit exception for completed Codex prompt text. Usage events include the workgroup name, cumulative session IN/OUT/TOTAL, latest Codex turn IN/OUT, provider row counts, and a source/function pipeline so a developer can see what the Python reader returned and where it stopped. Never log exception messages, local paths, terminal output, or title text in runtime events.
- Templates own presentation. Add a factory to `GridlineTemplate` for a new template-owned surface, then render it in the template folder. Pass typed snapshots to the view; do not duplicate data logic for each skin.
- `MainTemplateDropdownActionRow` lives in its own file at `gridline/template/main_template/MainTemplateDropdownActionRow.swift`, beside `MainTemplateDropdownPanel.swift`; each type has a separate Swift source file for easy discovery.
- For a dropdown/popover in the main template, reuse `gridline/template/main_template/MainTemplateDropdownPanel.swift`: `MainTemplateDropdownPanel` is the palette-aware shell, and `MainTemplateDropdownActionRow` is the matching hoverable action row. Read `gridline/template/main_template/README.md` for its uses; search `rg -n 'MainTemplateDropdownPanel|MainTemplateDropdownActionRow' gridline/template gridline/Sources/Gridline` before building a new dropdown style.
- The in-repository copy is Gridline's source of truth for any external reference tool. Link the copied source and its UI component from this guide and `gridline_debug/INDEX.md`.
- Provider token-price values are API-equivalent estimates, not subscription charges. Mark estimates clearly and report models without a known rate instead of counting them as `$0`.

## Current product and behavior context

- Gridline is a native macOS workspace for organizing parallel Codex CLI work. A named work group represents a task or project, keeps its project folder visible, and can be collapsed or selected from the sidebar.
- The current UI starts one Codex terminal in an empty work group. Do not describe multiple terminals per group or user-created shell sessions as current UI behavior unless the implementation changes.
- The workspace has one, two, or three group columns. It saves group names, folders, collapse state, terminal labels, each terminal's last working directory, per-terminal font size and height, and layout metadata in ~/Library/Application Support/Gridline/workspace.json (numbered copies scope their saved data to their version). Terminals start at 10 pt and can zoom down to 6 pt; their pane heights resize independently.
- Saved workspace metadata is not a saved process. Quitting or rebuilding ends live shell/Codex PTYs; reopening creates fresh terminal processes in each terminal's last working directory, and Codex terminals launch a fresh Codex session there.
- Session labels begin with a short label such as Codex. A terminal title event may update an automatic label. A user-edited label takes precedence. Do not infer a task title when the CLI has not sent one.
- The workspace directory prompt supports its documented cd, pwd, and ls interactions, folder completion, and folder navigation. It validates paths and does not execute arbitrary shell commands. New groups and sessions use the saved default folder.
- Gridline Debug is a separate native app. Its listen-only pointer monitor examines Accessibility elements from the paired Gridline process. Hover previews and outlines an element; clicking pins it and records a selection.
- The inspector combines selected Accessibility metadata with Gridline's semantic event log at gridline_debug/events.jsonl. Copy LLM context includes the element, likely source path, an rg command, and relevant nearby events. It does not store terminal text, control values, credentials, or screenshots in reports.
- Gridline's UI, data model, and workflow are original to this project. gridline_research/REPOSITORY_RESEARCH.md is a working reference for product and code research. Learn a focused idea; do not copy another app's screen, branding, source, or internal protocols.

## Source map and stable identifiers

The compact, maintained mapping from identifiers to likely implementation files is gridline_debug/INDEX.md. Start there. Main paths include:

- Grid, toolbar, directory prompt, workspace data, and terminal sessions: gridline/Sources/Gridline/Workspace.swift.
- Main template palette, work-group card, and terminal-label presentation: gridline/template/main_template/.
- Main template reusable dropdown surface/action row: `gridline/template/main_template/MainTemplateDropdownPanel.swift` and `gridline/template/main_template/MainTemplateDropdownActionRow.swift`; used by workspace controls, directory and skill-script popovers, work-group actions, and usage settings.
- Provider process detection, refresh scheduling, and typed snapshots: `gridline/Sources/Gridline/ProviderUsageService.swift`; bundled Codex and Claude readers: `gridline/usage/`.
- Per-terminal token counts and API-equivalent estimates: `TerminalUsageStatus` in `gridline/Sources/Gridline/ProviderUsageService.swift` streams `gridline/usage/terminal_usage.py`; the workgroup header presents the typed snapshot. `gridline.workspace.terminalUsage.disable` in the usage popover pauses the watcher and hides/shows every workgroup's IN/OUT row.
- Shared Ponytail vendor updates: **Workspace controls → Ponytail source…** → confirmation → `PonytailVendorUpdateModel` in `gridline/Sources/Gridline/CodexHooks.swift` → `gridline/hooks/update_ponytail_vendor.py`, which runs `git pull --ff-only` only in `hook_vendor/.ponytail-upstream` and refreshes ignored `hook_vendor/ponytail/`. It never pulls Gridline's own repo. First-start bootstrap uses `ensure` and does not pull when a prepared copy already exists.
- Codex hook setup and compaction rows: each work group's **ellipsis → Project hooks…** → `CodexHooksPanel` in `gridline/Sources/Gridline/CodexHooks.swift` → `gridline/hooks/install_project_hooks.py`; setup writes `.codex/hooks.json` and `.codex/ponytail.md` under that group's live terminal Git root or saved folder. An installed Ponytail project shows its small vendored icon left of the group ellipsis; clicking it opens an editor for that group's `.codex/ponytail.md` in `gridline/template/main_template/MainTemplatePonytailDocumentViewer.swift`, and Save writes changes back to that file. The card inspects the active terminal folder and rechecks when the folder or hooks panel changes. Live shell cwd is tracked on `TerminalSession.currentDirectory` and persisted per session as `SavedSession.workingDirectory` in `gridline/Sources/Gridline/Workspace.swift`; a restarted Codex terminal opens a fresh Codex session in that folder. Project `PreCompact`/`PostCompact` events go through `gridline/hooks/gridline_codex_hook.py` into `events.jsonl`; the hook drops prompt, transcript, and cwd fields and writes only while the paired Debug log view is active.
- Provider status presentation: `gridline/template/main_template/MainTemplateUsageStatusView.swift`, called through `GridlineTemplate.makeUsageStatusView`.
- Semantic app event schema and path: gridline/Sources/Gridline/DebugEvents.swift.
- Inspector selection, hover, copy, and reports: gridline_debug/Inspector/Sources/MyLLMDebug/InspectorStore.swift and InspectorView.swift. Full-width live logs: DebugTimelineStore.swift and DebugTimelineView.swift in the same folder.
- Accessibility hit-test fields: gridline_debug/Inspector/Sources/MyLLMDebug/DebugElement.swift.
- Accessibility identifier to likely Swift action/event map and copied context: gridline_debug/Inspector/Sources/MyLLMDebug/GridlineCodeContext.swift.
- Non-interactive hover border overlay: gridline_debug/Inspector/Sources/MyLLMDebug/HoverHighlight.swift.
- App/package build: gridline/build-app.sh; rebuild-on-change watcher: gridline_debug/watch-build.sh.

Stable identifiers include gridline.group.new, gridline.session.newCodex, gridline.workspace.directoryCommand, gridline.workspace.groupSidebar, gridline.group.toggle.<UUID>, gridline.group.close.<UUID>, gridline.group.name.<UUID>, gridline.group.addCodex.<UUID>, gridline.group.folder.<UUID>, gridline.session.label.<UUID>, gridline.session.close.<UUID>, gridline.session.terminal.<UUID>, and gridline.layout.columns. Search identifiers or visible titles with rg 'gridline\.|visible title' gridline/Sources gridline_debug.

Per-terminal controls also use `gridline.session.zoomOut.<UUID>`, `gridline.session.zoomIn.<UUID>`, `gridline.session.fontSize.<UUID>`, and `gridline.session.resizeHeight.<UUID>`.

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

## Inspector permissions and diagnostic data

- If Gridline Debug reports Accessibility permission needed, use Set up access… and enable the matching app in macOS Accessibility settings: gridline_debug/Gridline Debug.app for main, or the paired version's inspector app.
- If Accessibility is active but pointer monitoring is unavailable, check Privacy & Security → Input Monitoring and restart the matching inspector.
- Use ./reset_gridline_accessibility.sh to list or reset only Gridline app permission entries. Preserve its explicit confirmation; never reset the global Accessibility service. Resetting closes and relaunches the selected app pair and ends its terminal sessions.
- gridline_debug/events.jsonl contains semantic UI actions, terminal lifecycle events, safe Codex compaction metadata, and Debug-only Swift/Python stage traces, not terminal output. Gridline Debug's **Codex hooks** filter shows compaction start/complete and hook setup rows. gridline_debug/build/latest-status.json is the last build result; latest-errors.txt is the compact diagnostic; latest.log is full compiler output. Reports live under gridline_debug/reports/; .gitignore keeps generated reports and build diagnostics out of Git.
- To inspect exactly the logs matching the user's current Debug window, run `./gridline_debug/inspect-logs.sh showUserlogFilters --format llm`. It reads `gridline_debug/user-log-view.json`, which Gridline Debug updates when Show, Workgroup, Search, or Following changes and when new timeline rows arrive. The command applies those Show, Workgroup, and Search filters to the same `timeline.jsonl`, reports whether the window is open, and emits the latest 30 matches as structured JSON with recorded details and code-path steps expanded to repo-relative file locations; pass `--limit 0` for all matches. For a user asking to see full log output, use `./gridline_debug/inspect-logs.sh showUserlogFilters --format text --limit N` and paste its complete output without a summary; `N` is the number of matching entries, not printed text lines. If `window_active` is false, the displayed controls are the last recorded view, not a currently open window. Use `./gridline_debug/inspect-logs.sh --category all --limit 30` only when the user asks for an independent Everything view rather than their current filters.
- AX inspection only covers elements exposed in the target app's Accessibility tree. The hierarchy does not promise exact Swift source line numbers. Use the index and code-context mapping rather than guessing.

### Swift and external-script runtime state

Use the source that owns the state; compiler output alone cannot explain a running usage status.

| Question | Where to inspect | What it tells you |
| --- | --- | --- |
| Did either app build? | `gridline_debug/build/latest-status.json`, `latest-errors.txt`, and `latest.log` | Build result, compact errors, and full compiler output; these are not runtime logs. |
| Are Gridline and its monitor running? | `ps` process list | Process names and parent relationships without printing command arguments. |
| What log entries is the user currently viewing? | `./gridline_debug/inspect-logs.sh showUserlogFilters --format llm` | Reads the live Show, Workgroup, Search, and Following state, then prints structured JSON entries with diagnostic details and repo-relative file/symbol code paths. Add `--limit 0` after the command to print all matches. |
| Which workgroup did I type into, and what IN/OUT totals did the Python reader return? | Open Gridline Debug, then inspect the “Last terminal clicked” card or filter recent events by workgroup name, `terminal.targeted`, `terminal.inputSubmitted`, `workspace.terminalUsageStatusChanged`, or `workspace.terminalUsageMonitorFailed`. Events include the saved workgroup name beside its UUID. | The usage row shows cumulative IN/OUT/TOTAL counts, rows read/parsed, provider match status/reason, candidate count, and a compact Swift-to-Python source/function pipeline. Submitted input events contain only the Unicode-scalar character count after Enter; they never include typed content, terminal output, local paths, or exception messages. Diagnostics are collected only while the matching inspector is open. |
| Where did that state come from? | `TerminalUsageStatus` in `gridline/Sources/Gridline/ProviderUsageService.swift` and `gridline/usage/terminal_usage.py` | Swift launches the Python JSON-lines reader, decodes each snapshot, then emits a debug event only when that terminal's diagnostic state changes. |
| How should external execution be traced? | `DebugEvents.configurePythonProcess` / `recordExternalProcess` in `gridline/Sources/Gridline/DebugEvents.swift`; `gridline/runtime/gridline_trace.py` | Python `debug_event(FEATURE, message, ...)` emits a `GRIDLINE_DEBUG` record with the exact `FEATURE - message` prefix and safe counts; the Swift bridge stores it as `runtime.pythonDebug`. Use a stable feature name such as `TERMINAL_HEADER` so Debug can filter it. Log only when the feature state changes. For frequently polled native commands, record failures only; routine start/success events flood the log. Never log prompts, transcripts, terminal output, paths, or exception messages. |
| Is the Python source syntactically valid? | `python3 -B -c 'import ast, pathlib; ast.parse(pathlib.Path("gridline/usage/terminal_usage.py").read_text())'` | Parses the script without creating bytecode files; this does not exercise provider matching. |

Gridline Debug's lower log panel defaults to **Everything**. Its Show menu filters by event category, while Workgroup and Search further narrow the visible rows. The live-view shell command above mirrors those controls. Each terminal submission row reports safe character counts and does not include submitted text in `events.jsonl`; completed Codex prompts are kept in the separate local timeline while Gridline Debug is open. Use Search for a workgroup name, event, feature prefix such as `TERMINAL_HEADER`, or session UUID.

Useful focused commands from the repository root:

~~~sh
cat gridline_debug/build/latest-status.json
cat gridline_debug/build/latest-errors.txt
tail -n 40 gridline_debug/build/latest.log
ps -axo pid=,ppid=,stat=,comm= | rg 'Gridline|MyLLMDebug|watch-build|Python'
rg 'terminal.targeted|workspace.terminalUsageStatusChanged|workspace.terminalUsageMonitorFailed' gridline_debug/events.jsonl | tail -n 40
~~~

For live Swift inspection, attach Xcode's LLDB to the Gridline PID and set a breakpoint on `TerminalUsageStatus.apply`. Inspect the snapshot's `status`, `diagnostic`, and `candidateCount` fields. Use `thread backtrace all` for a stalled call. Do not dump terminal view state or buffers. Python reader exceptions are converted to a status event containing only the exception type; a nonzero reader exit is recorded separately. The reader catches recoverable polling errors and continues on the next three-second cycle.

## Product direction and handoff

Current product priorities are a clearer project-first terminal grid, reliable group and session labels, saved organizational context, and trustworthy session state. Potential follow-up work includes resizable grid proportions, a focused/maximized terminal, session state cues based on reliable signals, restored ordering/selection, and a supported Codex title hook or app-server event. Treat these as direction, not shipped features.

For a focused behavior change, read the relevant section in gridline_debug/INDEX.md, search the mapped source, then open only that file. For Version 1 requests, confirm the target copy and use its matching source, index, and watcher. After implementation, keep gridline_debug/INDEX.md accurate and update this guide only when durable project context changes.

## Swift code hygiene and LLM navigation

Use this chapter when changing Swift code. Start with the relevant row in the source map below, search for the exact type or behavior with `rg`, then read the containing file and its direct callers. Keep edits local to the owning layer and update the source map when a type moves.

### References

- [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/) — names should be clear at the call site, and documentation should explain non-obvious behavior.
- [Swift Protobuf style guide](https://github.com/apple/swift-protobuf/blob/main/Documentation/STYLE_GUIDELINES.md) — useful conventions for file/type organization, access control, and comments.
- [John Sundell: Encapsulating SwiftUI view styles](https://www.swiftbysundell.com/articles/encapsulating-swiftui-view-styles) — a design reference for keeping repeated SwiftUI presentation reusable and distinct from view behavior.

These are references, not a requirement to copy another project's architecture. Apply the ideas in ways that fit Gridline's existing layers and stable behavior.

### Repository conventions

- Prefer one primary type per file when it has an independent responsibility or is a likely edit target. Keep small, tightly coupled private SwiftUI helpers beside their owning view.
- Name files after their primary type or responsibility. Put shared app behavior in `gridline/Sources/Gridline/`, template presentation in `gridline/template/<template_id>/`, and inspector behavior in `gridline_debug/Inspector/Sources/MyLLMDebug/`.
- Keep provider parsing, process detection, persistence, and calculations out of SwiftUI views. Views present typed state and call shared actions; template-specific layout belongs in its template folder.
- Keep implementation details `private` unless another type or file needs them. Prefer named helpers to deeply nested conditional expressions, and document surprising behavior or non-obvious constraints.
- `gridline/Package.swift` lists Gridline Swift sources explicitly. Add every new app or template Swift file there. The inspector target discovers source files under its target path.
- Build the relevant app after Swift changes (`swift build` from its package, or use `./start.sh` when the main hot-reload pair is already intended to run). A successful app rebuild restarts that app and ends its live terminal processes. Do not add tests or run test suites unless requested.
- No Swift formatter or linter is configured in this repository. Keep edits consistent with nearby code and check whitespace with `git diff --check`; do not claim a formatter pass unless one is installed and actually run.

### Swift file map

| Area | Main type or responsibility | File | Search from repository root |
| --- | --- | --- | --- |
| App entry and menu commands | `GridlineApp` | `gridline/Sources/Gridline/GridlineApp.swift` | `rg -n 'struct GridlineApp|commands|CommandGroup' gridline/Sources/Gridline` |
| Workspace data, terminal process, and workspace actions | `SavedGroup`, `SavedSession`, `WorkspaceSnapshot`, `TerminalSession`, `WorkspaceStore` | `gridline/Sources/Gridline/Workspace.swift` | `rg -n 'struct SavedGroup|class TerminalSession|class WorkspaceStore|func runDirectoryCommand' gridline/Sources/Gridline/Workspace.swift` |
| Workspace and terminal presentation | `WorkspaceView`, directory prompt, terminal pane, transcription and skill UI | `gridline/Sources/Gridline/Workspace.swift` | `rg -n 'struct WorkspaceView|struct TerminalPane|DirectoryCommandField|SkillScriptDropdownView' gridline/Sources/Gridline/Workspace.swift` |
| Codex project hook installation and hook state view | `CodexHooksPanel`, `CodexHooksPanelModel` | `gridline/Sources/Gridline/CodexHooks.swift` | `rg -n 'CodexHooksPanel|CodexHooksPanelModel' gridline/Sources/Gridline/CodexHooks.swift` |
| Live voice capture and transcription | `AudioTranscriptionModel` | `gridline/Sources/Gridline/Workspace.swift` | `rg -n 'class AudioTranscriptionModel|AudioTranscriptionModel' gridline/Sources/Gridline` |
| Voice todo model and presentation | `VoiceTodoModel`, `VoiceTodoModalView` | `gridline/Sources/Gridline/VoiceTodo.swift` | `rg -n 'class VoiceTodoModel|struct VoiceTodoModalView|VoiceTodoFormatting' gridline/Sources/Gridline/VoiceTodo.swift` |
| Provider allowance and process usage state | `CodexUsageStatus`, `ProviderUsageStatus`, typed snapshots | `gridline/Sources/Gridline/ProviderUsageService.swift` | `rg -n 'class CodexUsageStatus|class ProviderUsageStatus|struct ProviderUsageSnapshot|refreshProcessStatus' gridline/Sources/Gridline/ProviderUsageService.swift` |
| Semantic event names and logging | `DebugEvents` | `gridline/Sources/Gridline/DebugEvents.swift` | `rg -n 'enum DebugEvents|static func' gridline/Sources/Gridline/DebugEvents.swift` |
| Template types, context, and selection | `GridlineTemplate`, `GridlineWorkGroupCardContext`, catalog/store | `gridline/template/TemplateCatalog.swift` | `rg -n 'struct GridlineTemplate|struct GridlineWorkGroupCardContext|enum GridlineTemplateCatalog|class GridlineTemplateStore' gridline/template/TemplateCatalog.swift` |
| Main template factories | `makeWorkGroupCard`, `makeUsageStatusView` | `gridline/template/main_template/MainTemplateDefinition.swift` | `rg -n 'extension GridlineTemplate|makeWorkGroupCard|makeUsageStatusView' gridline/template/main_template` |
| Main template workgroup and terminal tile UI | `MainTemplateWorkGroupCard`, private terminal card | `gridline/template/main_template/MainTemplateWorkGroupCard.swift` | `rg -n 'struct MainTemplateWorkGroupCard|struct MainTemplateTerminalCard' gridline/template/main_template` |
| Main template usage meter | `MainTemplateUsageStatusView` | `gridline/template/main_template/MainTemplateUsageStatusView.swift` | `rg -n 'struct MainTemplateUsageStatusView|UsageRefreshSettingsPopover' gridline/template/main_template` |
| Main template reusable dropdown shell | `MainTemplateDropdownPanel` | `gridline/template/main_template/MainTemplateDropdownPanel.swift` | `rg -n 'struct MainTemplateDropdownPanel' gridline/template/main_template` |
| Main template reusable dropdown row | `MainTemplateDropdownActionRow` | `gridline/template/main_template/MainTemplateDropdownActionRow.swift` | `rg -n 'struct MainTemplateDropdownActionRow' gridline/template/main_template` |
| Inspector element/event model | `DebugElement`, `InspectorEvent` | `gridline_debug/Inspector/Sources/MyLLMDebug/DebugElement.swift` | `rg -n 'struct DebugElement|struct InspectorEvent' gridline_debug/Inspector/Sources/MyLLMDebug` |
| Inspector state and report writing | `InspectorStore` | `gridline_debug/Inspector/Sources/MyLLMDebug/InspectorStore.swift` | `rg -n 'class InspectorStore|func copyElementContext|func saveReport' gridline_debug/Inspector/Sources/MyLLMDebug` |
| Accessibility-to-source context for LLMs | `GridlineCodeContext` | `gridline_debug/Inspector/Sources/MyLLMDebug/GridlineCodeContext.swift` | `rg -n 'enum GridlineCodeContext|sourcePath\(|makeCopyText' gridline_debug/Inspector/Sources/MyLLMDebug` |
| Inspector window | `InspectorView` | `gridline_debug/Inspector/Sources/MyLLMDebug/InspectorView.swift` | `rg -n 'struct InspectorView' gridline_debug/Inspector/Sources/MyLLMDebug` |
| Accessibility change observer | `AXChangeWatcher` | `gridline_debug/Inspector/Sources/MyLLMDebug/AXChangeWatcher.swift` | `rg -n 'class AXChangeWatcher' gridline_debug/Inspector/Sources/MyLLMDebug` |
| Hover outline overlay | `HoverHighlight` | `gridline_debug/Inspector/Sources/MyLLMDebug/HoverHighlight.swift` | `rg -n 'class HoverHighlight|class HoverBorderView' gridline_debug/Inspector/Sources/MyLLMDebug` |
| Inspector app entry | `MyLLMDebugApp` | `gridline_debug/Inspector/Sources/MyLLMDebug/MyLLMDebugApp.swift` | `rg -n 'struct MyLLMDebugApp' gridline_debug/Inspector/Sources/MyLLMDebug` |
| Swift icon tools | Debug and version app icon generators | `gridline/tools/` | `rg -n 'NSImage|CGContext|write' gridline/tools --glob '*.swift'` |
| SwiftPM source inclusion | Gridline package manifest | `gridline/Package.swift` | `rg -n 'sources:|resources:|template/' gridline/Package.swift` |
| Inspector SwiftPM configuration | Inspector package manifest | `gridline_debug/Inspector/Package.swift` | `rg -n 'executableTarget|platforms|products' gridline_debug/Inspector/Package.swift` |

### Audit notes

- The repository's Swift sources were reviewed for navigation, naming, access control, force unwraps, and obvious asynchronous state hazards. A provider usage refresh could previously restore a stale cost snapshot after an asynchronous process scan; the scan now preserves the latest cost fields when applying its result.
- The fixed Accessibility Settings URL now uses optional handling instead of a force unwrap. `fatalError` in `HoverHighlight`'s coder initializer is intentional because that AppKit view is created programmatically.
- `GridlineCodeContext.searchTerm(...)` states the inspector's source-search priority as ordered checks; keep this mapping explicit so copied LLM context points to a useful symbol instead of relying on a nested conditional.
- `Workspace.swift` and `VoiceTodo.swift` contain multiple related model and view types. Use the map above to jump directly to the owning type; split these files only when changing a cohesive area and preserve package inclusion, Accessibility identifiers, persistence, and behavior.
