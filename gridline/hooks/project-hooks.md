# Project hooks

## Where this lives in code

- [`CodexHooks.swift`](../Sources/Gridline/CodexHooks.swift)
- [`MainTemplateWorkGroupCard.swift`](../template/main_template/MainTemplateWorkGroupCard.swift)
- [`install_project_hooks.py`](install_project_hooks.py)
- [`gridline_codex_hook.py`](gridline_codex_hook.py)
- [`update_ponytail_vendor.py`](update_ponytail_vendor.py)
- [`gridline_debug/INDEX.md`](../../gridline_debug/INDEX.md)

## Behavior

The work-group menu resolves project hooks against the live terminal folder when available, otherwise the saved project folder. The installer uses the containing Git root when there is one. It merges Gridline's hook entries into project `.codex/hooks.json` while retaining other hooks, and rejects malformed configuration or an unmarked Gridline-managed hook directory rather than replacing it.

Ponytail project setup and Codex compaction logging are separate actions. Compaction hook records omit prompt, transcript, and working-directory fields and are written only while the paired Gridline Debug view is active. The shared Ponytail source updater pulls only in its isolated vendor checkout; it does not pull Gridline's repository.

See the [Gridline Debug index](../../gridline_debug/INDEX.md) for event names and log inspection. Keep provider hook adapters and project setup in `gridline/hooks/`, not in template views.

## Checkpoint

- [x] Installer, work-group entry point, updater, and compaction hook paths are mapped.
- [x] Project hook merging and diagnostic boundaries are documented from the inspected implementation and project guide.
- [ ] Recheck this page if the installer changes its project-root resolution or owned-file policy.
