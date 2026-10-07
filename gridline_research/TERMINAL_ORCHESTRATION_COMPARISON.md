# Gridline and Terminal Orchestration Tools

Research notes comparing Gridline with Herdr, Ghostty, and cmux. Reviewed on 2026-10-07.

## Research method

This was a read-only review of Gridline's `AGENTS.md`, `gridline_debug/INDEX.md`, and the mapped workspace implementation in `gridline/Sources/Gridline/Workspace.swift`. Documentation navigation and relevant feature sections were reviewed on the Herdr, Ghostty, and cmux documentation sites. No repository files were changed during the research pass.

## What Gridline does today

Gridline organizes project work into named groups. Each group has a folder and, in the current UI, one Codex terminal slot. Users can collapse groups, choose a one to three column grid, rename terminals, and adjust terminal font size and height. Group and session metadata persists between launches, but terminal processes do not: reopening starts fresh processes.

Gridline also includes local audio transcription and Voice todo workflows, a latest-thread token total, and a separate inspector that connects selected UI elements to semantic events and likely code paths. The inspector is a debugging aid, not a terminal control interface.

## What the other products add

### Herdr: agent-aware terminal workspace and automation layer

Herdr organizes real terminals into workspaces, tabs, and split panes. It recognizes supported coding agents and tracks states such as `working`, `blocked`, `done`, `idle`, and `unknown`. State can roll up to tabs and workspaces so attention goes to the project or agent that needs it.

Herdr's CLI and socket API let scripts or another agent create and organize terminal locations, start supported agents, submit prompts, read terminal output, send keys, and wait for agent states. A background server keeps processes running when clients detach. Its docs also cover session restore and remote machines over SSH.

Relevant docs:

- [Concepts](https://herdr.dev/docs/concepts/)
- [Agents](https://herdr.dev/docs/agents/)
- [Agent automation](https://herdr.dev/docs/agent-automation/)
- [Session state and restore](https://herdr.dev/docs/session-state/)
- [Persistence and remote access](https://herdr.dev/docs/persistence-remote/)
- [Connecting machines](https://herdr.dev/docs/connecting-machines/)

### cmux: multi-agent terminal workspace and control surface

cmux layers workspaces, split panes, terminal and browser surfaces, notifications, and agent integrations over Ghostty. Its CLI and socket API control workspaces and surfaces. Its notification panel can surface agent events and take the user to the workspace that needs attention.

The docs also describe reusable workspace layouts and commands, notification hooks, agent hooks for restoring supported sessions, task monitoring, workspace groups, and cloud machines. Session restore brings back app-owned layout and metadata; supported agents can resume when cmux has captured their native session ID. It does not checkpoint arbitrary live process state.

Relevant docs:

- [Getting started](https://cmux.com/docs/getting-started)
- [Concepts](https://cmux.com/docs/concepts)
- [Session restore](https://cmux.com/docs/session-restore)
- [Workspace groups](https://cmux.com/docs/workspace-groups)
- [Notifications](https://cmux.com/docs/notifications)
- [CLI and socket API](https://cmux.com/docs/api)
- [Task Manager](https://cmux.com/docs/task-manager)
- [Claude Code Teams integration](https://cmux.com/docs/agent-integrations/claude-code-teams)

### Ghostty: terminal emulator

Ghostty is a terminal emulator, not an agent orchestrator. Its docs focus on terminal performance and capabilities: native UI, GPU rendering, tabs and splits, themes, keybindings, shell integration, SSH support, and terminal protocols. On macOS it also exposes AppleScript automation for querying and controlling windows, tabs, terminals, splits, and input.

That AppleScript support gives scripts a way to operate Ghostty, but Ghostty's docs do not describe Herdr-style agent lifecycle tracking or cmux-style agent workflow dashboards.

Relevant docs:

- [About Ghostty](https://ghostty.org/docs/about)
- [Features](https://ghostty.org/docs/features)
- [Configuration](https://ghostty.org/docs/config)
- [Shell integration](https://ghostty.org/docs/features/shell-integration)
- [SSH](https://ghostty.org/docs/features/ssh)
- [AppleScript](https://ghostty.org/docs/features/applescript)
- [Terminal API (VT)](https://ghostty.org/docs/vt)

## Gaps in Gridline compared with Herdr and cmux

### Agent operations and lifecycle

Gridline currently has places to organize Codex work, but it does not expose a general way to manage multiple agents as running work. It has no documented agent lifecycle states, attention rollup, completion or blocked notifications, or built-in prompt, wait, inspect, and respond control loop.

### Terminal orchestration

Gridline's group grid is not a general terminal layout system. The current UI has one Codex terminal slot per group, rather than arbitrary split panes, multiple terminal surfaces or browser surfaces within a group, or reusable workspace layouts. It has no documented CLI or socket API for externally creating and controlling terminal workspaces.

### Persistence and remote work

Gridline saves organizational metadata, not live terminal processes. Its documented workflow does not include a persistent background terminal server, detachable clients, native agent conversation restore, or remote machine/session management like the workflows documented by Herdr and cmux.

### Automation and integrations

Gridline has local skill workflows and semantic debugging events, but those are not an external terminal automation interface. Compared with Herdr and cmux, Gridline lacks documented commands or APIs for creating workspaces, sending agent prompts, reading terminal output, waiting for lifecycle changes, and integrating agent events with notifications or custom actions.

## Product category summary

Herdr and cmux are workflow dashboards for running and coordinating coding agents. Gridline today is a project-first organizer that launches Codex terminals and adds local productivity tools around that workspace. Ghostty is a terminal engine and user-facing terminal application that another product, such as cmux, can build on.

The largest difference is agent operations: Gridline organizes where Codex work happens, while Herdr and cmux also provide documented ways to observe, control, automate, and resume agent work.



https://www.youtube.com/watch?v=NsgjLVOcVMs