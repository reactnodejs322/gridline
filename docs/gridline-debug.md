# Gridline Debug

## Where this lives in code

- [inspect-logs.sh](../gridline_debug/inspect-logs.sh)
- [InspectorStore.swift](../gridline_debug/Inspector/Sources/MyLLMDebug/InspectorStore.swift)
- [DebugTimelineStore.swift](../gridline_debug/Inspector/Sources/MyLLMDebug/DebugTimelineStore.swift)
- [DebugEvents.swift](../gridline/Sources/Gridline/DebugEvents.swift)

## Quick reference: inspect the logs currently shown in Gridline Debug

When the user asks you to look at their Gridline logs, run this from the repository root:

~~~sh
./gridline_debug/inspect-logs.sh showUserlogFilters --format llm
~~~

This reads Gridline Debug's live **Show**, **Workgroup**, and **Search** selections from `gridline_debug/user-log-view.json`, then prints matching timeline rows as structured JSON, including recorded details and each Swift/Python code-path step expanded to its repo-relative file location. The Debug app refreshes that state when a filter changes or the timeline updates, so this command follows the user's current view instead of assuming `--category all`. It also reports whether the Debug window is open and whether **Following** is on. By default it prints the latest 30 matching rows; append `--limit 0` to print every match. Use `--format text` for compact log lines with readable code paths.

When the user asks to see the full latest log output, run `./gridline_debug/inspect-logs.sh showUserlogFilters --format text --limit N` (for example, `--limit 50`) and paste the complete command output without summarizing it. `--limit` counts matching log entries, not physical display lines; the command returns fewer if fewer entries match. Use `--format llm` when structured JSON is useful for analysis. See [Inspector permissions and diagnostic data](#inspector-permissions-and-diagnostic-data) for details and independent-filter commands.
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

## Checkpoint

- [x] The original AGENTS.md guidance in the sections above is preserved here.
- [ ] Recheck paths and behavior when the owning implementation changes.
