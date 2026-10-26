# Workspace and terminals

## Where this lives in code

- [Workspace.swift](../gridline/Sources/Gridline/Workspace.swift)
- [MainTemplateWorkGroupCard.swift](../gridline/template/main_template/MainTemplateWorkGroupCard.swift)
- [ProviderUsageService.swift](../gridline/Sources/Gridline/ProviderUsageService.swift)

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

## Checkpoint

- [x] The original AGENTS.md guidance in the sections above is preserved here.
- [ ] Recheck paths and behavior when the owning implementation changes.
