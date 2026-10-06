# myllm_debug

Use this folder as the short, data-rich handoff between a UI change request and the coding LLM.

1. Read [`INDEX.md`](INDEX.md) first. It maps common UI elements directly to Swift files and stable Accessibility identifiers.
2. Start `Gridline Debug.app`, allow macOS Accessibility access, and turn on inspection.
3. Hover over a Gridline control to preview it, then click it. The clicked control stays selected in the inspector.
4. Read the selected element's description and likely Swift code path at the top. **Copy LLM context** includes a plain-language description of what the control does, its source path, a grep command, and only matching behavior events near that click. Unrelated terminal lifecycle events are filtered out; if no expected event was recorded, the copied context says so. The lower panel continues to show Gridline actions such as `workgroup.created` live.
5. Save a context report when useful. It lands in `reports/` as Markdown and JSON with the selected element, likely source path, captured clicks, Accessibility change notifications, Gridline's event log, and latest build errors.
6. Start from the project root with `./start.sh`. It builds and opens both apps, then watches Swift edits and relaunches both apps after a successful build.

The inspector uses macOS Accessibility APIs and a listen-only mouse event tap. It filters to Gridline's bundle ID (`local.gridline.terminal`), so hovers and clicks in the inspector or other apps are ignored. It does not type, click, or change controls for you. It records labels and identifiers, never a control's AX value or terminal contents. Reports remain local.

The build script signs Gridline Debug with a stable designated requirement based on its bundle ID. This lets macOS keep Accessibility authorization across local rebuilds. Click **Set up access…** in Gridline Debug to open the Accessibility settings pane; remove old Inspector entries, then add and enable `gridline_debug/Gridline Debug.app`. macOS requires you to enable the app yourself; Gridline Debug checks for the grant automatically after you return. Hover and click events are accepted only from the paired Gridline bundle ID and its current `gridline.pid`.

The workflow is informed by [Loupe](https://github.com/smughead/Loupe)'s hover/annotate/copy loop and the [macOS Accessibility Client](https://github.com/drewster99/macos-accessibility-client)'s code for resolving global clicks to Accessibility elements and watching AX events. We implemented a small Gridline-specific inspector rather than copying either repository.

## Build the inspector

```sh
./gridline_debug/build-inspector.sh
open "gridline_debug/Gridline Debug.app"
```

SwiftUI is compiled native code, so this is build-and-relaunch rather than in-process hot reload. Each successful reload ends current terminal processes (including active Codex sessions); workspace labels and folders are restored, but terminal output and live sessions are not. Save work first. On build errors, the existing apps stay open and the diagnostics are written to `build/latest-errors.txt` and `build/latest.log`.


## Isolated version copies

Run `./start_versions.sh` from the main project root. Create makes a source snapshot under `gridline_versions/version_N`; Debug lists available snapshots and launches the selected copy; Stop closes the selected version’s Gridline, Gridline Debug, and watcher. The manager prints running state and writes `gridline_versions/runtime-status.json`. Each copy has a `VERSION` file. Its build scripts assign distinct Gridline and inspector bundle identifiers, process names, Dock number badge, isolated workspace data, and version-specific event/report folders. The inspector's Accessibility hit test reads its paired Gridline bundle ID from its own app metadata. macOS Accessibility authorization may need to be enabled for each versioned inspector app separately.
