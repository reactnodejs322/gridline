# Project hooks

## Where this lives in code

- [`CodexHooks.swift`](../Sources/Gridline/CodexHooks.swift)
- [`Workspace.swift`](../Sources/Gridline/Workspace.swift)
- [`MainTemplateWorkGroupCard.swift`](../template/main_template/MainTemplateWorkGroupCard.swift)
- [`install_project_hooks.py`](install_project_hooks.py)
- [`gridline_context.cjs`](gridline_context.cjs)
- [`gridline_codex_hook.py`](gridline_codex_hook.py)
- [`update_ponytail_vendor.py`](update_ponytail_vendor.py)
- [Project hook configuration](../../.codex/hooks.json)
- [`gridline_debug/INDEX.md`](../../gridline_debug/INDEX.md)

## Behavior

The work-group menu resolves project hooks against the live terminal folder when available, otherwise the saved project folder. The installer uses the containing Git root when there is one. It merges Gridline's hook entries into project `.codex/hooks.json` while retaining other hooks, and rejects malformed configuration or an unmarked Gridline-managed hook directory rather than replacing it. Hook commands resolve the current Git root when they run, so moving a checkout does not leave stale absolute paths; non-Git folders use the hook process's current directory.

When configured `.codex` guides exist, Gridline prepares a managed Claude context hook under `.claude/hooks/gridline/` and merges `SessionStart` and `UserPromptSubmit` handlers into `.claude/settings.json`. Installing Ponytail triggers Claude setup, as does opening a work-group card or changing its project folder. Claude receives those guides at startup and on every prompt. The Project hooks panel has a separate action to enable `.codex/RUST_SKILL.md` for Claude. Work-group icons are evaluated against the active provider's hook configuration and helper files; existing Claude hooks are retained.

Claude's per-hook context limit is 10,000 characters. Gridline registers numbered parts of at most 4,000 Unicode code points each, with one spare part, and updates the registration when the work-group card sees a guide's size change. The icon indicates a configured hook, not proof of delivery. If guide text grows past the registered parts before they refresh, the last part reports that the guidance is incomplete.

Ponytail project setup and Codex compaction logging are separate actions. Compaction hook records omit prompt, transcript, and working-directory fields and are written only while the paired Gridline Debug view is active. The shared Ponytail source updater pulls only in its isolated vendor checkout; it does not pull Gridline's repository.

See the [Gridline Debug index](../../gridline_debug/INDEX.md) for event names and log inspection. Keep provider hook adapters and project setup in `gridline/hooks/`, not in template views.

## Checkpoint

- [x] Installer, work-group entry point, updater, and compaction hook paths are mapped.
- [x] Project hook merging and diagnostic boundaries are documented from the inspected implementation and project guide.
- [x] Hook commands use runtime project-root resolution instead of install-time absolute paths.
- [ ] Recheck this page if the installer changes its project-root resolution or owned-file policy.
