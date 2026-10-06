# Gridline

### Grep guide for LLMs

Use `rg` to jump to a README section by its heading or search terms:

```sh
rg -n '^#{1,3} ' README.md
rg -n -i 'version 1|hot reload|PID pairing|accessibility|terminal workspace|work groups|product direction|repository research' README.md
```

To find Version 1 implementation code, search its UI map and Swift sources:

```sh
rg -n -i 'FEATURE OR CONTROL WORDS' gridline_versions/version_1/gridline_debug/INDEX.md gridline_versions/version_1/gridline/Sources gridline_versions/version_1/gridline_debug/Inspector/Sources
```

Replace `FEATURE OR CONTROL WORDS` with terms from the requested behavior. For the main app, use `gridline/Sources` and `gridline_debug/INDEX.md` plus `gridline_debug/Inspector/Sources` instead.

## LLM context index

1. **Choose what to edit** — [main app or a numbered version](#llm-handoff-choose-the-copy-first)
   - A. Main Gridline: `gridline/` and `gridline_debug/`
   - B. Version 1: `gridline_versions/version_1/gridline/` and `gridline_versions/version_1/gridline_debug/`
2. **Run and reload** — [launchers, hot reload, and PID pairing](#launchers-hot-reload-and-pairing)
3. **Ask for a change** — [short Version 1 prompt](#short-prompt-for-version-1)
4. **Find the implementation** — [app behavior](#how-the-apps-work) and [source map](#llm-map)
5. **Understand the design** — [product direction and terminal research](#product-direction)
6. **Search for details** — use the [grep guide](#grep-guide-for-llms) and `gridline_debug/INDEX.md`.

## LLM handoff: choose the copy first

This is a native macOS SwiftUI terminal workspace and its companion Accessibility tool. **Always decide which copy you are changing before editing.** The main app and each numbered version are separate source trees with different app identities, saved workspace data, logs, and paired Gridline Debug apps.

| Target | Edit Gridline here | Edit Gridline Debug here | Start / rebuild that target |
| --- | --- | --- | --- |
| Main Gridline | `gridline/` | `gridline_debug/` | From this project root, run `./start.sh`. |
| Version 1 | `gridline_versions/version_1/gridline/` | `gridline_versions/version_1/gridline_debug/` | From this root run `./start_versions.sh`, choose **Debug**, then select `version_1`; or run `./start.sh` from inside `gridline_versions/version_1/`. |
| Another version | `gridline_versions/version_N/gridline/` | `gridline_versions/version_N/gridline_debug/` | Select that exact version using `./start_versions.sh`, or run its own `start.sh`. |

Do not edit the root `gridline/` when asked to change Version 1. Do not copy changes between the main app and a version unless specifically requested. A version is an isolated snapshot. The root `README.md` is the authoritative guide for every copy; each version folder has a short local note and its own `AGENTS.md`.

### Launchers, hot reload, and pairing

- **`./start.sh` at the project root** starts the main Gridline + Gridline Debug pair and watches main Swift sources. Leave its terminal open. Press **Ctrl-C** to stop its watcher.
- **`./start_versions.sh` at the project root** prompts for **Create**, **Debug**, or **Stop**. Create copies the main source into the next `gridline_versions/version_N` and starts it. Debug starts the selected version's own watcher and app pair. Stop closes only that version's pair and watcher. The menu shows running state.
- **`./stop.sh` at the project root** stops the main pair and every numbered version. It stops their watchers and Gridline-launched terminal child processes too, including shell and Codex PIDs, then refreshes the PID status files. This ends active terminal sessions.
- **Hot reload means rebuild and relaunch.** After a successful Swift change, the watcher rebuilds both apps in that copy and restarts them so the native code loads. This ends that copy's live shell and Codex sessions; group labels and folders persist, but terminal processes/output do not. Save terminal work before a reload. A failed build leaves the current apps open and records errors in that copy's `gridline_debug/build/latest-errors.txt` and `latest.log`.
- Each copy has unique bundle IDs and process names. Main uses `local.gridline.terminal` / `local.myllm.debuginspector`; Version 1 uses `local.gridline.terminal.version1` / `local.myllm.debuginspector.version1`. Gridline Debug is built with the matching target bundle ID and PID-file path, accepts Accessibility hits only from that exact Gridline process, and refuses an ambiguous process match. The watcher writes the live Gridline PID to that copy's `gridline_debug/build/gridline.pid`; Gridline Debug refreshes the file from the unique matching bundle-ID process. This keeps each debug app attached to its own Gridline copy.
- `gridline_versions/runtime-status.json` lists each numbered copy's Gridline PID, Gridline Debug PID, watcher PID, bundle IDs, and folder. For main, see `gridline_debug/build/gridline.pid`, `gridline_debug/build/watch.pid`, and `gridline_debug/build/latest-status.json`. For Version 1, the equivalent files live under `gridline_versions/version_1/gridline_debug/build/`.

Do not start a second watcher for a copy that the status already shows as running. Let its existing watcher reload after edits. If it is stopped, launch that target once with the command above and keep the watcher terminal open. App display names are **Gridline**, **Gridline Debug**, **Gridline Version 1**, and **Gridline Debug Version 1**.

### Short prompt for Version 1

The table and notes above provide the source paths, launcher, hot-reload behavior, and app pairing. To request a Version 1 change, just tell the LLM:

> Read `README.md`. I'm working on Gridline Version 1. Implement: **[describe the feature or fix]**.

For the main app, replace “Gridline Version 1” with “the main Gridline app.”

## How the apps work

### Startup and rebuild loop

`start.sh` runs `gridline_debug/watch-build.sh` in the foreground. The watcher fingerprints Swift files under both app source folders and `gridline/tools/`, plus the shared logo and icon/build scripts, builds the two Swift packages, and packages them as `Gridline.app` and `gridline_debug/Gridline Debug.app`. After a successful first build it closes existing app processes and opens one instance of each. It writes the live Gridline PID to `gridline_debug/build/gridline.pid`; Gridline Debug resolves the unique live process with its paired bundle ID, refreshes this PID file if needed, and refuses to inspect an ambiguous match. Later successful builds repeat that close-and-open step and refresh the PID. A failed build does not replace the running apps; details are written to `gridline_debug/build/latest.log`, `latest-errors.txt`, and `latest-status.json`.

This is native compile-and-relaunch, not in-process code injection. Relaunching Gridline terminates its local shell and Codex PTYs. Group names, folders, collapse state, and session labels are saved in `~/Library/Application Support/Gridline/workspace.json`; terminal output and live processes are not restorable.

### Inspector event flow

`gridline_debug/Inspector` is a separate native app. After macOS Accessibility permission is granted, its listen-only pointer monitor checks the Accessibility element under the pointer. The hit test accepts only Gridline's bundle identifier, `local.gridline.terminal`. Hover updates the preview; a click pins that element and adds it to Recent Clicks. The inspector reads Gridline's separate semantic action log from `gridline_debug/events.jsonl` and combines it with the selected Accessibility metadata when it saves a report.

The inspector does not read terminal text or control values. Its top card describes the last clicked Gridline element, including the Accessibility identifier and likely Swift code path. **Copy LLM context** copies a plain-language action summary, the source path, an `rg` search command, and only matching semantic events recorded near the click; unrelated lifecycle noise is filtered out. If no expected event was recorded, the copied text says so. While hovering Gridline, a transparent mint border outlines the Accessibility element under the pointer without intercepting clicks. The lower panel shows recent Gridline behavior/state events live, such as `workgroup.created` after creating a work group. These events are read from `gridline_debug/events.jsonl`, not terminal output. Accessibility reports identify runtime roles, labels, stable identifiers, and parent hierarchy; use `gridline_debug/INDEX.md` to map those back to Swift source.

### Permission recovery

If Gridline Debug says **Accessibility permission needed**, click **Set up access…**. It opens the Accessibility settings pane. Enable the matching app for the target you are using: `gridline_debug/Gridline Debug.app` for main, or that version's `gridline_debug/Gridline Debug Version N.app` for a numbered copy. Remove stale entries named Inspector if any remain. macOS requires this explicit user action; the app cannot grant itself access. Gridline Debug rechecks authorization while open. If its status says Accessibility is active but macOS refused the pointer monitor, also check **Privacy & Security → Input Monitoring** and restart the matching Gridline Debug app.

After a user reports a behavior change, keep this README and `gridline_debug/INDEX.md` aligned with the implementation. Put durable architecture, launch, permission, and data-flow notes here; keep the index short and focused on source lookup.

### LLM map

- Read [`gridline_debug/INDEX.md`](gridline_debug/INDEX.md) first for the compact UI-to-source map and stable Accessibility identifiers.
- Main app UI, groups, sessions, persistence: `gridline/Sources/Gridline/Workspace.swift`.
- Gridline app events: `gridline/Sources/Gridline/DebugEvents.swift`.
- Inspector UI and selection/report workflow: `gridline_debug/Inspector/Sources/MyLLMDebug/InspectorView.swift` and `InspectorStore.swift`.
- Inspector Accessibility hit testing: `gridline_debug/Inspector/Sources/MyLLMDebug/DebugElement.swift`.
- Build and launch watcher: `start.sh` → `gridline_debug/watch-build.sh`.
- Research notes and references: [`gridline/docs/REPOSITORY_RESEARCH.md`](gridline/docs/REPOSITORY_RESEARCH.md).

For focused changes, read the one mapped source file rather than loading the full project into context.

Gridline is a native macOS workspace for running Codex CLI alongside the other pieces of a project. The main organizing unit is a piece of work—such as **Working on webapp** or **Working on job hunter**. Each work group has one full-width terminal, can be collapsed when you want to focus elsewhere, and remembers its project folder. The × control closes the whole work group and its terminal.

The **Terminal workspace** row includes a compact directory prompt. The empty prompt shows the current default path; enter `cd`, `pwd`, or `ls` and press Return. `cd` changes the default folder (including `cd ~` and relative paths); Tab completes folder names, and choosing a suggestion navigates there immediately. `pwd` shows the full current path, and `ls` opens a dropdown as wide as the prompt with a terminal-style path/command line and folders/files grouped and sorted. Clicking a folder in the listing navigates into it; files are labeled and shown but not opened. The prompt validates paths and does not execute arbitrary shell commands. The default folder is persisted in `~/Library/Application Support/Gridline/workspace.json` and is used by new work groups and newly started terminal sessions.

The hamburger control beside the workspace icon opens a work-group sidebar overlay at the far left. It sits over the grid without shrinking or rebuilding terminal panes. Choose a group to scroll its card into view; its border glows cyan briefly and fades after five seconds. The sidebar only navigates; it does not close sessions.

The project borrows useful interaction ideas from existing terminal apps. It does not copy their application code or try to reproduce every feature they offer. Gridline's interface, data model, and workflow are being built for this specific task: keeping multiple Codex efforts understandable at a glance.

## What we learned from other terminals

| App | Useful idea | How Gridline applies it |
| --- | --- | --- |
| [Wave Terminal](https://docs.waveterm.dev/workspaces) | Saved workspaces keep related tabs, layouts, and terminal history together. Its blocks can be arranged into a workspace. | A named work group keeps its project folder and related Codex or shell sessions together. |
| [Warp](https://docs.warp.dev/terminal/sessions) | Session navigation and restoration make it easier to return to ongoing work. | Gridline saves group names, terminal labels, folders, and the workspace layout between launches. |
| [cmux](https://cmux.com/) | A native Mac interface, clear workspace navigation, splits, and attention cues suit concurrent agent work. | Gridline uses native macOS controls and gives each task a visible, collapsible home. |
| [iTerm2](https://stage.iterm2.com/3.3/documentation-one-page.html) | Each split is a real terminal session, with familiar keyboard-driven pane navigation. | Every Gridline terminal is a local pseudo-terminal running a normal shell and the user's installed CLI tools. |

These are product references, not source-code templates. Gridline's application code is written for this project. SwiftTerm is used as a focused open-source terminal/PTY dependency so we do not need to write a VT terminal emulator from scratch; it is not a copied app or UI. See its [repository and license](https://github.com/migueldeicaza/SwiftTerm).

For the repository-by-repository code review, including which projects are easiest to learn from and why Gridline uses SwiftTerm 1.18 on this Mac, see [Repository research](gridline/docs/REPOSITORY_RESEARCH.md).

## Product direction

### Work groups first

- A work group has an editable name, project folder, and collapse/expand control.
- Example groups: `Working on webapp`, `Working on job hunter`, `Release checks`.
- Groups can contain multiple Codex sessions and ordinary shell sessions.
- Add, close, rename, and rearrange work without losing the other groups.

### Let the terminal tell us what it can

- A session starts with a short label such as `Codex` or `Shell`.
- If a running CLI sends a terminal title update, show that title on its session. This lets tools that publish task names identify their own work.
- The user can always give a session a custom label. A custom label takes precedence over later terminal title updates.
- Keep the group label and session label separate: the group says *which task*; a session label says *what this terminal is doing within that task*.

Codex's terminal title behavior can vary by CLI version and session state. The label should fall back to the user's own name when no useful title is sent; Gridline must not pretend it can read a task name the CLI did not provide.

### Native and local

- Build a real macOS app with SwiftUI and AppKit, not an HTML wrapper.
- Start the user's shell and `codex` as local interactive terminal processes.
- Let Codex retain its normal login, settings, approvals, and CLI behavior.
- Keep workspace metadata on this Mac. Never save API keys or copy terminal output into Gridline's workspace file.
- Use native keyboard shortcuts, resizable windows, directory pickers, and macOS text editing behavior.

## Current MVP

- Native macOS window with a grid of named, collapsible work groups.
- Editable work-group and terminal labels.
- Multiple live local Codex and shell sessions per group.
- Separate project folder per group.
- Session labels follow terminal title-change events until manually renamed.
- Workspace metadata restores after quitting and reopening the app.
- One, two, or three work-group columns.
- Companion Accessibility inspector and structured UI feedback reports in `gridline_debug/`.
- Swift build watcher that saves concise compiler errors without killing live Codex sessions.

## Next steps

1. Make the grid adjustable by dragging, and support a focused/maximized terminal.
2. Add session state cues such as running, waiting for input, and finished, without guessing from arbitrary terminal text.
3. Restore group/session ordering and selected group, and show a helpful empty state for a new project.
4. Investigate a supported Codex hook or app-server event for authoritative thread titles; keep manual labels as the reliable fallback.
5. Add a signed app bundle and a simple drag-to-Applications distribution path when the core interaction feels right.

## Build and run

Requirements: macOS 13 or newer, Xcode Command Line Tools, and the Codex CLI installed for Codex sessions.

```sh
./gridline/build-app.sh
open gridline/Gridline.app
```

For the normal development workflow, use `./start.sh` to build and open both apps and watch Swift sources.

To make an isolated snapshot before experimenting, run `./start_versions.sh`. Choose **Create** to copy the app sources, debug app, and shared logo into the next `gridline_versions/version_N` folder and launch that copy. Choose **Debug** to select and relaunch an existing copy, or **Stop** to close just that version’s Gridline, Gridline Debug, and hot-reload watcher. The menu shows each app and watcher’s running state; `gridline_versions/runtime-status.json` records their PIDs, bundle IDs, and version folder for quick LLM inspection. Versioned app bundles include the capitalized version in their names, such as `Gridline Version 1.app` and `Gridline Debug Version 1.app`. A version copy uses unique app bundle IDs and process names, stores its workspace and debug events beside its own code, shows its version in Gridline Debug, and adds a large numbered badge at the lower-left of the Gridline Dock icon. Gridline Debug only inspects its paired Gridline. The root project remains the editable main copy.

Run `./reset_gridline_accessibility.sh` to list the currently running Gridline apps and their PIDs. Choose the Gridline you are working with, then type `RESET` to clear its and its paired Gridline Debug permission records. The script closes and relaunches only that pair, updates the Gridline PID link, and opens Accessibility settings; macOS requires you to add or enable Debug manually. Restarting Gridline ends its live terminal sessions. Other Gridline versions stay open. Full Disk Access is not needed.

The first build fetches SwiftTerm through Swift Package Manager. The app saves group and session labels in `~/Library/Application Support/Gridline/workspace.json`; live terminal processes themselves cannot be resumed after the app exits, so reopening creates fresh shells and Codex sessions.

For pointer inspection, click tracking, app logs, issue reports, and Swift rebuild diagnostics, see [`gridline_debug/README.md`](gridline_debug/README.md). The external inspector requires macOS Accessibility permission to inspect other apps.

## Project layout

- `gridline/Sources/Gridline/` — original Gridline app and workspace implementation
- `gridline/Package.swift` — macOS app target and terminal-engine dependency
- `gridline/build-app.sh` — builds and packages a local `.app` bundle
- `logo/Gridline2x.png` — the one shared editable logo source; the inspector bug badge is generated at build time
- `gridline_debug/` — compact LLM context map, UI inspector, reports, event logs, and build diagnostics
- `start_versions.sh` and `gridline_versions/` — create, launch, inspect status, or stop isolated numbered app snapshots
- `reset_gridline_accessibility.sh` — list Gridline Accessibility permissions and interactively reset only Gridline-related app entries
- Both apps package Dock icons generated from `logo/Gridline2x.png`; Gridline Debug adds its yellow bug badge, and each numbered Gridline copy adds a large lower-left version badge.

## References

- [Wave workspaces](https://docs.waveterm.dev/workspaces) and [layout concepts](https://docs.waveterm.dev/gettingstarted)
- [Warp terminal sessions](https://docs.warp.dev/terminal/sessions)
- [cmux](https://cmux.com/)
- [iTerm2 split panes](https://stage.iterm2.com/3.3/documentation-one-page.html)
- [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) terminal engine
