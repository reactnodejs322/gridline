# Code navigation

## Where this lives in code

- [Workspace.swift](../gridline/Sources/Gridline/Workspace.swift)
- [TemplateCatalog.swift](../gridline/template/TemplateCatalog.swift)
- [GridlineCodeContext.swift](../gridline_debug/Inspector/Sources/MyLLMDebug/GridlineCodeContext.swift)
- [Package.swift](../gridline/Package.swift)

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
## Grep guide

Use `rg` to find a topic before opening a large source file.

~~~sh
# Browse the keyword guide, feature documents, compact UI index, and research headings.
rg -n '^#{1,3} ' AGENTS.md docs gridline_debug/INDEX.md gridline_research/REPOSITORY_RESEARCH.md

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
## Source map and stable identifiers

The compact, maintained mapping from identifiers to likely implementation files is gridline_debug/INDEX.md. Start there. Main paths include:

- Grid, toolbar, directory prompt, workspace data, and terminal sessions: gridline/Sources/Gridline/Workspace.swift.
- Main template palette, work-group card, and terminal-label presentation: gridline/template/main_template/.
- Main template reusable dropdown surface/action row: `gridline/template/main_template/MainTemplateDropdownPanel.swift` and `gridline/template/main_template/MainTemplateDropdownActionRow.swift`; used by workspace controls, directory and skill-script popovers, work-group actions, and usage settings.
- Provider process detection, refresh scheduling, and typed snapshots: `gridline/Sources/Gridline/ProviderUsageService.swift`; bundled Codex and Claude readers: `gridline/usage/`.
- Per-terminal token counts and API-equivalent estimates: `TerminalUsageStatus` in `gridline/Sources/Gridline/ProviderUsageService.swift` streams `gridline/usage/terminal_usage.py`; the workgroup header presents the typed snapshot. `gridline.workspace.terminalUsage.disable` in the usage popover pauses the watcher and hides/shows every workgroup's IN/OUT row.
- Shared Ponytail vendor updates: **Workspace controls → Ponytail source…** → confirmation → `PonytailVendorUpdateModel` in `gridline/Sources/Gridline/CodexHooks.swift` → `gridline/hooks/update_ponytail_vendor.py`, which runs `git pull --ff-only` only in `hook_vendor/.ponytail-upstream` and refreshes ignored `hook_vendor/ponytail/`. It never pulls Gridline's own repo. First-start bootstrap uses `ensure` and does not pull when a prepared copy already exists. The main work-group card also shows the Ferris mascot beside the Ponytail icon when the active project contains `.codex/RUST_SKILL.md`; its hover label names the file.
- Codex hook setup and compaction rows: each work group's **ellipsis → Project hooks…** → `CodexHooksPanel` in `gridline/Sources/Gridline/CodexHooks.swift` → `gridline/hooks/install_project_hooks.py`; setup writes `.codex/hooks.json` and `.codex/ponytail.md` under that group's live terminal Git root or saved folder. **AI workflow…** opens a disposable Codex terminal at the resolved project root inside its modal; it is not saved to `workspace.json` and closes with the modal. Its guides stay in Gridline resources, and the selected guide's full contents are staged in the terminal; AI workflow setup does not write project `.codex/` files. The LLM must wait for explicit user approval before editing project Markdown. The main card shows hook-backed document icons for Ponytail, Rust Skill, and System Design; clicking each opens the shared editor in `gridline/template/main_template/MainTemplateMarkdownDocumentViewer.swift`. The card inspects the active terminal folder and refreshes its registered document list. Live shell cwd is tracked on `TerminalSession.currentDirectory` and persisted per session as `SavedSession.workingDirectory` in `gridline/Sources/Gridline/Workspace.swift`; a restarted Codex terminal opens a fresh Codex session in that folder. Project `PreCompact`/`PostCompact` events go through `gridline/hooks/gridline_codex_hook.py` into `events.jsonl`; the hook drops prompt, transcript, and cwd fields and writes only while the paired Debug log view is active.
- Provider status presentation: `gridline/template/main_template/MainTemplateUsageStatusView.swift`, called through `GridlineTemplate.makeUsageStatusView`.
- Semantic app event schema and path: gridline/Sources/Gridline/DebugEvents.swift.
- Inspector selection, hover, copy, and reports: gridline_debug/Inspector/Sources/MyLLMDebug/InspectorStore.swift and InspectorView.swift. Full-width live logs: DebugTimelineStore.swift and DebugTimelineView.swift in the same folder.
- Accessibility hit-test fields: gridline_debug/Inspector/Sources/MyLLMDebug/DebugElement.swift.
- Accessibility identifier to likely Swift action/event map and copied context: gridline_debug/Inspector/Sources/MyLLMDebug/GridlineCodeContext.swift.
- Non-interactive hover border overlay: gridline_debug/Inspector/Sources/MyLLMDebug/HoverHighlight.swift.
- App/package build: gridline/build-app.sh; rebuild-on-change watcher: gridline_debug/watch-build.sh.

Stable identifiers include gridline.group.new, gridline.session.newCodex, gridline.workspace.directoryCommand, gridline.workspace.groupSidebar, gridline.group.toggle.<UUID>, gridline.group.close.<UUID>, gridline.group.name.<UUID>, gridline.group.addCodex.<UUID>, gridline.group.folder.<UUID>, gridline.session.label.<UUID>, gridline.session.close.<UUID>, gridline.session.terminal.<UUID>, and gridline.layout.columns. Search identifiers or visible titles with rg 'gridline\.|visible title' gridline/Sources gridline_debug.

Per-terminal controls also use `gridline.session.zoomOut.<UUID>`, `gridline.session.zoomIn.<UUID>`, `gridline.session.fontSize.<UUID>`, and `gridline.session.resizeHeight.<UUID>`.

## Checkpoint

- [x] The original AGENTS.md guidance in the sections above is preserved here.
- [ ] Recheck paths and behavior when the owning implementation changes.
