# Coding Agent Guide

Use this map first, then read the one relevant index or source file. Keep this guide as the technical handoff; README.md is written for people exploring Gridline.

## Context table

| Task | Start here | Then inspect or search |
| --- | --- | --- |
| Choose the app copy | Main app: gridline/ + gridline_debug/. Versioned copy: gridline_versions/version_N/. | Use the target table under Copy selection and isolation. |
| Find a Gridline control or behavior | gridline_debug/INDEX.md | gridline/Sources/Gridline/Workspace.swift; search the control title or gridline.* identifier. |
| Change inspector behavior | gridline_debug/INDEX.md | gridline_debug/Inspector/Sources/MyLLMDebug/InspectorView.swift or InspectorStore.swift. |
| Trace terminal launch, labels, or persistence | gridline/Sources/Gridline/Workspace.swift | Search TerminalSession, WorkspaceStore, addSession, or workspace.json. |
| Build, launch, or reload | start.sh → gridline_debug/watch-build.sh | gridline/build-app.sh and gridline_debug/build-inspector.sh. |
| Debug Accessibility or app pairing | gridline_debug/INDEX.md | gridline_debug/Inspector/Sources/MyLLMDebug/DebugElement.swift; check that bundle ID and PID file belong to the same copy. |
| Read product research | gridline_research/REPOSITORY_RESEARCH.md | Research is background context, not a source code template. |
| Update public-facing product copy | README.md | Keep implementation maps and LLM instructions here in AGENTS.md, not in the human README. |

## Grep guide

Use rg to find a topic before opening a large source file:

~~~sh
# Browse this guide, the compact UI index, and research headings.
rg -n '^#{1,3} ' AGENTS.md gridline_debug/INDEX.md gridline_research/REPOSITORY_RESEARCH.md

# Find main app behavior, visible labels, or stable Accessibility identifiers.
rg -n -i 'work group|codex|collapse|folder|sidebar|directory command|terminal title|gridline\.' gridline/Sources gridline_debug/Inspector/Sources

# Find a behavior in a numbered snapshot; replace version_1 if needed.
rg -n -i 'FEATURE OR CONTROL WORDS' gridline_versions/version_1/gridline_debug/INDEX.md gridline_versions/version_1/gridline/Sources gridline_versions/version_1/gridline_debug/Inspector/Sources

# Find launcher, pairing, or permission behavior.
rg -n 'watch-build|GridlineTargetBundleID|GridlineTargetPIDFile|gridline\.pid|Accessibility' start.sh start_versions.sh stop.sh gridline_debug gridline_versions
~~~

For a main app change, search gridline/Sources and gridline_debug/Inspector/Sources. For a version change, search only that version's two app trees. Replace FEATURE OR CONTROL WORDS with terms from the requested behavior. Prefer opening one relevant Swift file after locating it rather than loading the repository broadly.

## Copy selection and isolation

Always decide which copy the user means before editing. The main app and numbered versions are separate source trees with their own app identities, workspace data, event logs, and paired inspectors.

| Target | Gridline source | Inspector source | Start or debug |
| --- | --- | --- | --- |
| Main Gridline | gridline/ | gridline_debug/ | From the project root, run ./start.sh. |
| Version 1 | gridline_versions/version_1/gridline/ | gridline_versions/version_1/gridline_debug/ | Run ./start_versions.sh, choose Debug, and select version_1; or run that copy's ./start.sh. |
| Another version | gridline_versions/version_N/gridline/ | gridline_versions/version_N/gridline_debug/ | Select that exact version with ./start_versions.sh, or run its own start.sh. |

Do not edit root gridline/ when asked to change Version 1. Do not copy changes between the main app and a version unless asked. A version is an isolated snapshot with its own root VERSION, Gridline bundle ID, inspector target bundle ID, workspace data, and debug event log. Keep those values scoped to that version. The root README.md is the human product overview; each version has its own local note and AGENTS.md when present.

## Project layout

- gridline/ contains the main native macOS app, Swift package, app build scripts, and app-specific notes.
- gridline_debug/ contains the companion inspector, its Swift package, INDEX.md, behavior logs, reports, and build diagnostics.
- gridline_research/ contains product and repository research, including comparisons with other terminal projects.
- logo/Gridline2x.png is the shared editable logo source. The inspector build generates its bug-badge variant from this file.
- The root contains README.md, this AGENTS.md, start.sh, start_versions.sh, and stop.sh.
- Swift Package Manager checkouts and build products live under .build/; .gitignore excludes them. Commit Package.swift and Package.resolved, not .build/.

## Implementation rules

- Before changing app behavior, read gridline_debug/INDEX.md for the compact map from UI behavior and Accessibility identifiers to source files.
- Reuse existing functions, views, styles, and shared helpers. Extend an existing implementation when possible; do not create duplicate code or parallel styling systems for the same behavior.
- Keep Gridline implementation in gridline/ and inspector implementation in gridline_debug/. Put cross-app launch/build coordination in the root launcher or gridline_debug/watch-build.sh.
- Keep the apps native SwiftUI/AppKit and preserve stable Accessibility identifiers and meaningful semantic events.
- Never write terminal output, control values, credentials, or API keys to inspector logs or reports. Terminal text and keystrokes are not captured by the inspector.
- Keep README and index paths aligned with the current folder structure. Keep the README human-facing; put coding-agent context in this file and concise UI lookup details in gridline_debug/INDEX.md.

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

## Build, launch, and reload

- From the root, ./start.sh builds and opens one main Gridline and one matching Gridline Debug, then watches Swift sources. Leave its terminal open; press Ctrl-C to stop the watcher.
- ./start_versions.sh offers Create, Debug, and Stop. Create makes the next isolated snapshot. Debug launches the selected version. Stop closes only that version's pair and watcher.
- ./stop.sh stops the main pair and numbered versions, including watchers and Gridline-launched terminal child processes. This ends active terminal sessions.
- A successful Swift rebuild closes and relaunches the affected app pair so native changes load. It ends that copy's live shell and Codex sessions. Save terminal work before changing Swift files while a watcher is running. A failed build leaves the current apps open and writes diagnostics under that copy's gridline_debug/build/.
- start.sh runs gridline_debug/watch-build.sh in the foreground. The watcher builds both packages, packages Gridline.app and Gridline Debug.app, and opens one instance of each after a successful first build.
- The watcher writes the live Gridline PID to that copy's gridline_debug/build/gridline.pid. Gridline Debug reads GridlineTargetBundleID and GridlineTargetPIDFile, resolves the sole live process for that bundle ID, refreshes the PID file, and refuses inspection if the match is ambiguous. Keep target bundle ID and PID file paired to the same copy.
- gridline_versions/runtime-status.json lists numbered copies' Gridline PID, inspector PID, watcher PID, bundle IDs, and folder. Main diagnostics are in gridline_debug/build/; version diagnostics are in the matching version tree.
- Do not start a second watcher when the target is already running. Let its watcher reload the apps.

## Inspector permissions and diagnostic data

- If Gridline Debug reports Accessibility permission needed, use Set up access… and enable the matching app in macOS Accessibility settings: gridline_debug/Gridline Debug.app for main, or the paired version's inspector app.
- If Accessibility is active but pointer monitoring is unavailable, check Privacy & Security → Input Monitoring and restart the matching inspector.
- Use ./reset_gridline_accessibility.sh to list or reset only Gridline app permission entries. Preserve its explicit confirmation; never reset the global Accessibility service. Resetting closes and relaunches the selected app pair and ends its terminal sessions.
- gridline_debug/events.jsonl contains semantic UI actions and terminal lifecycle events, not terminal output. gridline_debug/build/latest-status.json is the last build result; latest-errors.txt is the compact diagnostic; latest.log is full compiler output. Reports live under gridline_debug/reports/; .gitignore keeps generated reports and build diagnostics out of Git.
- AX inspection only covers elements exposed in the target app's Accessibility tree. The hierarchy does not promise exact Swift source line numbers. Use the index and code-context mapping rather than guessing.

## Product direction and handoff

Current product priorities are a clearer project-first terminal grid, reliable group and session labels, saved organizational context, and trustworthy session state. Potential follow-up work includes resizable grid proportions, a focused/maximized terminal, session state cues based on reliable signals, restored ordering/selection, and a supported Codex title hook or app-server event. Treat these as direction, not shipped features.

For a focused behavior change, read the relevant section in gridline_debug/INDEX.md, search the mapped source, then open only that file. For Version 1 requests, confirm the target copy and use its matching source, index, and watcher. After implementation, keep gridline_debug/INDEX.md accurate and update this guide only when durable project context changes.
