# Reusable logic and bundled tools

## Where this lives in code

- [ProviderUsageService.swift](../gridline/Sources/Gridline/ProviderUsageService.swift)
- [terminal_usage.py](../gridline/usage/terminal_usage.py)
- [DebugEvents.swift](../gridline/Sources/Gridline/DebugEvents.swift)
- [install_project_hooks.py](../gridline/hooks/install_project_hooks.py)

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

## Checkpoint

- [x] The original AGENTS.md guidance in the sections above is preserved here.
- [ ] Recheck paths and behavior when the owning implementation changes.
