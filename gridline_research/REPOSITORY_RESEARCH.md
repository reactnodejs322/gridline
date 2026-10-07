# Repository research for Gridline

This is a working field guide for learning from existing projects while keeping Gridline's implementation original. I inspected repository structure and the files listed below, not just their product pages. The takeaways are descriptions of behavior and design; Gridline does not copy their application source.

## Short answer

**Wave is the easiest app-level reference for an LLM to make a focused workspace/layout change in.** Its workspace UI and layout logic are in recognizable, separately named TypeScript files. The particular files are a manageable size: `workspace.tsx` (176 lines), `workspaceswitcher.tsx` (264 lines), and `workspace-layout-model.ts` (438 lines). That does not make the entire Wave repository small: it has a large React frontend and a Go/Electron backend, and the model still connects to global state and RPC APIs.

**cmux is the closest product and platform reference for Gridline.** It is a native Swift/AppKit macOS terminal that supports agent workflows. Its title integration is especially relevant: the code has a dedicated Codex hook that looks up Codex's own thread title and sends it back to the right terminal surface. This is more authoritative than guessing from terminal text. But cmux is now a very large application: the checkout inspected contains about 2,640 Swift source files, plus a CLI, native libraries, and a Ghostty integration. It is a good place to inspect a specific feature; it is not a good whole-app base for this small project.

**Agents Office is a different kind of reference: a task dispatch app with a 3D office UI.** Its office metaphor shows assigned task progress and context, while a local server routes real work to role-specific Claude agents and saves deliverables into a Markdown notes folder (“Brain”). It is not primarily a viewer for arbitrary agents running in terminals. The repository labels v3 as Beta; its README describes six fixed departments and 35 configurable agent roles, team task splitting, skills and corrections, configured MCP connectors, browser use, and scheduled routines. Treat the roster size and animated office as UI/product choices, not evidence that dozens of agents are independently productive. The repo's noncommercial license and extra terms prohibit bundling it into another product or agent system.

**For our implementation, keep Gridline's app model and UI small and original, and use a focused terminal engine as a dependency.** Keep manual labels as the dependable fallback. Add a Codex-specific title hook only after its setup can be done without unexpectedly rewriting the user's Codex configuration.

## Repositories inspected

| Repository | What it is | Code inspected | Finding for Gridline |
| --- | --- | --- | --- |
| [manaflow-ai/cmux](https://github.com/manaflow-ai/cmux) | Native Swift/AppKit Mac terminal using Ghostty. | `Sources/TerminalController+AgentTitle.swift`, `CLI/CMUXCLI+CodexFireAndForgetHooks.swift`, and sidebar/workspace source. | Best native product reference. Its Codex hook reads the title Codex already stored and updates the matching terminal surface. Adapt the idea of an explicit title source and a small update message; do not lift its socket, persistence, or hook implementation. Its current source tree is too broad to navigate as one unit. |
| [ajsahni/agents-office](https://github.com/ajsahni/agents-office) | Local task dispatch app with an isometric office UI and a roster of Claude-based role agents. | Public README, changelog, roster description, setup and workflow documentation; source implementation not audited for this note. | Useful reference for task routing, role-specific instructions, persistent notes, feedback/skills, scheduled work, and approval gates. The office visualizes its own task system; it does not inspect arbitrary terminal agents. The README says agents do not get Bash, file tools, or subagents, so this is not a fleet of coding terminals. The repo calls v3 Beta and documents a noncommercial license with added restrictions, including no bundling into another product or agent system. The author product page says Codex works too, while the public repo README lists Claude Code or an Anthropic API key; verify the current build before assuming Codex support. |
| [wavetermdev/waveterm](https://github.com/wavetermdev/waveterm) | Workspace-oriented terminal app with a React/TypeScript frontend and Go/Electron services. | `frontend/app/workspace/workspace-layout-model.ts`, `frontend/app/workspace/workspace.tsx`, and `frontend/app/tab/workspaceswitcher.tsx`. | Best LLM-readable app-level example among those inspected. Keep layout/state decisions distinct from view components, and persist user workspace choices. The whole app has more global state and backend coupling than Gridline needs. |
| [migueldeicaza/SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) | Swift terminal emulator and local pseudo-terminal library. | `Sources/SwiftTerm/Mac/MacLocalTerminalView.swift`, `Sources/SwiftTerm/LocalProcess.swift`, plus the macOS getting-started sample. | Best fit for the low-level terminal job only. It provides a real PTY and terminal emulation, so Gridline can stay native without implementing VT/xterm behavior itself. Gridline's SwiftUI layout, labels, and work-group logic remain our code. |
| [zellij-org/zellij](https://github.com/zellij-org/zellij) | Rust terminal multiplexer/workspace. | `zellij-server/src/pane_groups.rs`, tiled-pane and tab management. | Useful ideas for pane grouping and session/layout separation. It is a terminal-first Rust server, not a native macOS GUI base; several central files are thousands of lines long. |
| [ghostty-org/ghostty](https://github.com/ghostty-org/ghostty) | Terminal emulator and reusable terminal engine in Zig. | `src/terminal/Terminal.zig` and `src/terminal/formatter.zig`. | Valuable engineering reference for terminal correctness. Low fit for editing Gridline UI: this is deep terminal machinery, and some core files are exceptionally large. Use a maintained terminal library instead of reimplementing this layer. |
| [openai/codex](https://github.com/openai/codex) | Codex CLI and related tooling. | Repository and `codex-rs` workspace structure. | Treat Codex as a program Gridline launches, not code Gridline forks. The current Rust workspace has well over 100 crates in `codex-rs`; it is far more code than needed to display sessions and their titles. |
| [wezterm/wezterm](https://github.com/wez/wezterm) | Rust terminal emulator and multiplexer. | README and multiplexing/shell-integration docs. | Helpful concepts for local and remote terminal lifecycle, but not a small native Swift workspace to use as an app skeleton. |

Product references also checked: [Warp session restore](https://docs.warp.dev/terminal/sessions), [iTerm2 split panes](https://stage.iterm2.com/3.3/documentation-one-page.html), and [Wave's workspace docs](https://docs.waveterm.dev/workspaces). These are useful interaction references; they are not open-source implementation candidates in the same way.

## Specific patterns worth adapting

### 0. Distinguish an agent work system from an agent monitor

Agents Office routes user requests into a known roster of role-specific workers, gives those workers notes, skills, and configured connectors, and collects deliverables in a local “Brain.” Its 3D office shows task state and contextual signals such as connector activity; it is a view of work dispatched by that application, not a general-purpose monitor that attaches to existing Codex or Claude terminal processes and infers their status.

This is a useful product distinction for Gridline. A terminal workspace can organize already-running sessions. A task dispatch system additionally defines agent roles, routes requests, provides task context, handles outputs, and coordinates dependencies or approvals. Adding a visual agent board alone would not provide those operations. For multi-agent coding, only parallelize tasks with clear boundaries and enough shared project context; an agent count does not solve missing requirements.

### 1. Separate work identity from terminal identity

Gridline has a group name such as **Working on webapp**, then individual terminal labels inside it. The group answers “what project/task is this?”; a child label answers “what is this terminal doing?”. This is the distinction the current UI should preserve.

### 2. Treat terminal title as metadata, not the whole truth

SwiftTerm reports terminal title changes through its process delegate. Gridline currently uses those events as an automatic label only while the user has not renamed the terminal. A manual name takes over from then on.

cmux goes further for Codex: its `runCodexNativeTitleSyncHook` resolves Codex's own stored thread title, checks that the session is still current, and sends a small title update to the matching surface. The useful pattern is *resolve authoritative title outside the view, then update a specific session*. The current cmux implementation depends on its own CLI, socket protocol, database reader, and session ledger; those pieces should not be copied into Gridline. If we implement this later, first investigate a supported Codex hook or app-server event and keep the bridge narrow.

### 3. Persist the workspace, not a fiction of a resumable process

Wave and Warp show the value of remembering layouts and workspaces. Gridline stores group names, folder paths, and terminal labels locally. A live shell/Codex process is different from saved UI metadata: after quitting, Gridline currently starts fresh terminal processes. Do not display a “restored” badge unless a process actually survived or resumed.

### 4. Use an established terminal engine

A terminal pane must handle keyboard input, PTY sizing, Unicode, escape sequences, colors, scrollback, and full-screen terminal apps. SwiftTerm provides that focused layer. Gridline should own its group/session model and native presentation, and delegate terminal emulation to the library.

## What we should build ourselves

- The work-group concept, editable labels, collapse state, and Gridline window design.
- A small model separating saved work groups/sessions from live PTY objects.
- Local persistence, project-folder selection, and clear lifecycle states.
- A narrow Codex-title adapter if a supported hook or app-server event is available.

Do not copy another app's screens, branding, whole source files, or internal storage/protocol implementation. Read a focused file to understand a pattern, then implement the behavior using Gridline's types and native macOS structure.

## SwiftTerm version note

This Mac has Xcode 15.4 with Swift 5.10. SwiftTerm 1.20.0 declares Swift tools 6.0, so Swift Package Manager cannot resolve it with the installed toolchain. Gridline therefore pins **SwiftTerm 1.18.0**, which declares tools version 5.9 and builds here. This is an ordinary package dependency, not copied SwiftTerm source. The app integration is in `gridline/Sources/Gridline/Workspace.swift`.

## Reading list

- [Agents Office repository and README](https://github.com/ajsahni/agents-office)
- [Agents Office changelog](https://github.com/ajsahni/agents-office/blob/main/CHANGELOG.md)
- [Agents Office agent roster](https://github.com/ajsahni/agents-office/blob/main/office.agents.json)
- [Agents Office license](https://github.com/ajsahni/agents-office/blob/main/LICENSE)
- [Agents Office author product page](https://sahni.ai/agentsofficev3/)
- [cmux Codex title hook](https://github.com/manaflow-ai/cmux/blob/main/CLI/CMUXCLI%2BCodexFireAndForgetHooks.swift)
- [cmux native title update](https://github.com/manaflow-ai/cmux/blob/main/Sources/TerminalController%2BAgentTitle.swift)
- [Wave layout model](https://github.com/wavetermdev/waveterm/blob/main/frontend/app/workspace/workspace-layout-model.ts)
- [Wave workspace view](https://github.com/wavetermdev/waveterm/blob/main/frontend/app/workspace/workspace.tsx)
- [SwiftTerm macOS local process terminal](https://github.com/migueldeicaza/SwiftTerm/blob/v1.18.0/Sources/SwiftTerm/Mac/MacLocalTerminalView.swift)
- [Zellij pane groups](https://github.com/zellij-org/zellij/blob/main/zellij-server/src/pane_groups.rs)
- [Ghostty terminal core](https://github.com/ghostty-org/ghostty/blob/main/src/terminal/Terminal.zig)
