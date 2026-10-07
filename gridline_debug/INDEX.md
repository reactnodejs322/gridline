# LLM entry point (read this first)

Keep this file as the compact map. Read the one relevant source file next; do not dump the whole repo into context.

## Fast paths

- Group grid, header, toolbar: `gridline/Sources/Gridline/Workspace.swift` → `WorkspaceView`
- Default folder prompt (`cd`, `pwd`, `ls`) and organized listing dropdown: `WorkspaceView.runDirectoryCommand()` → `WorkspaceStore.runDirectoryCommand(_:)` in `gridline/Sources/Gridline/Workspace.swift`
- Add/close sessions, collapse groups, folder selection, persistence: `gridline/Sources/Gridline/Workspace.swift` → `WorkspaceStore`
- Terminal process, label changes, Codex title event: `gridline/Sources/Gridline/Workspace.swift` → `TerminalSession`
- UI action log schema/path: `gridline/Sources/Gridline/DebugEvents.swift`
- External Gridline-only hover/click inspector, clipboard context, and report writer: `gridline_debug/Inspector/Sources/MyLLMDebug/InspectorStore.swift`
- Accessibility hit-test fields: `gridline_debug/Inspector/Sources/MyLLMDebug/DebugElement.swift`
- Non-interactive hover border overlay: `gridline_debug/Inspector/Sources/MyLLMDebug/HoverHighlight.swift`
- Accessibility identifier → likely Swift action/event map and LLM clipboard text: `gridline_debug/Inspector/Sources/MyLLMDebug/GridlineCodeContext.swift`
- Inspector UI, selected-element description, copy button, and live behavior log: `gridline_debug/Inspector/Sources/MyLLMDebug/InspectorView.swift`
- App/package build: `gridline/build-app.sh`; rebuild-on-change watcher: `gridline_debug/watch-build.sh`

## Stable Gridline identifiers

- `gridline.group.new` — create work group
- `gridline.session.newCodex` — create Codex terminal
- `gridline.workspace.directoryCommand` — `cd`/`pwd`/`ls` prompt for the saved default folder used by new groups and terminals
- `gridline.skillScript.menu` / `.dropdown` / `.audioToText` / `.transcriptionOptions` / `.speakerMode` / `.pauseMode` / `.startTranscription` / `.transcriptionModal` / `.transcriptionLoading` / `.transcript` / `.transcriptStats` / `.copyTranscript` / `.saveTranscript` — choose speaker-labeled diarization or faster pause-based paragraphs, then preview, copy, or save the transcript
- `gridline.skillScript.voiceTodo` — open the continuous local Voice todo capture modal; short mic chunks go through one local Whisper worker and the modal fills an editable text box
- `gridline.workspace.tab.workspace` / `.voiceTodo` — switch between the terminal workspace and Voice todo landing page; the Voice todo page opens the live capture modal
- `gridline.voiceTodo.open` / `.modal` / `.status` / `.start` / `.endProblem` / `.stop` / `.input` / `.meter` / `.confidence` / `.confidenceThreshold` / `.copy` / `.close` — Problem Notes are cached locally across app restarts and stay empty until “OK, problem” or “OK, next problem” meets the adjustable shared confidence threshold; the bottom waveform reflects mic level
- `gridline.workspace.groupSidebar` / `.panel` / `.item.<UUID>` — toggle the left overlay without resizing terminals; selecting a group scrolls to its card and briefly highlights its border
- `gridline.group.toggle.<UUID>` — collapse/expand group
- `gridline.group.close.<UUID>` — close the work-group cell and terminate every terminal inside it
- `gridline.group.header.<UUID>` — gray work-group header region (including empty header space)
- `gridline.group.card.<UUID>` — whole work-group card container
- `gridline.group.name.<UUID>` — group title
- `gridline.group.addCodex.<UUID>` — start the work group's single Codex terminal when its slot is empty; new shell sessions are disabled
- `gridline.group.folder.<UUID>` — project folder picker
- `gridline.session.label.<UUID>` / `gridline.session.zoomOut.<UUID>` / `gridline.session.zoomIn.<UUID>` / `gridline.session.fontSize.<UUID>` / `gridline.session.resizeHeight.<UUID>` / `gridline.session.close.<UUID>` — session label, per-terminal font zoom controls and size, bottom-edge height resize handle, and close control; font size and height persist per session
- `gridline.session.terminal.<UUID>` — native terminal surface, labeled with its session and work-group IDs; terminal text and keystrokes are not captured
- `gridline.layout.columns` — grid column choice

Search identifiers/titles with `rg 'gridline\.|visible title' gridline/Sources gridline_debug`.

## Debug data

- `events.jsonl` — semantic UI actions and terminal lifecycle events from Gridline; shown live in the inspector's lower behavior/state panel
- `build/latest-status.json` — last build status/time
- `build/latest-errors.txt` — compact compiler diagnostics; empty means last build succeeded
- `build/latest.log` — full compiler output
- `reports/issue-*.md` and matching `.json` — human-readable and structured selected-element context, code path hints, clicks, and app events
- The inspector listens for focus/title/value/layout AX notifications from the last clicked app and merges them into the click timeline.

## Important boundaries

- SwiftUI changes require compile + app restart; the watcher restarts both apps after successful builds, which ends live Gridline PTYs.
- Reports do not store terminal output, AX field values, credentials, or screenshots.
- **Copy LLM context** includes the clicked element, Accessibility metadata, likely Swift file/action, expected semantic event names, a literal `rg` command, and matching `events.jsonl` lines. Terminal lifecycle events are correlated by session ID; unrelated session starts are filtered out. Code path mapping lives in `GridlineCodeContext.swift`; unmapped controls use an explicit search fallback rather than a guessed source line.
- AX inspection works only for elements exposed by the target app's Accessibility tree. The AX hierarchy is not a promise of Swift source line numbers.
- Keep new Swift files and functions focused so an LLM can load only the relevant 100–150 lines.
