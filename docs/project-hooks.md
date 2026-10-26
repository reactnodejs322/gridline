# Project hooks

## Where this lives in code

- [CodexHooks.swift](../gridline/Sources/Gridline/CodexHooks.swift)
- [MainTemplateWorkGroupCard.swift](../gridline/template/main_template/MainTemplateWorkGroupCard.swift)
- [install_project_hooks.py](../gridline/hooks/install_project_hooks.py)
- [gridline_codex_hook.py](../gridline/hooks/gridline_codex_hook.py)
- [update_ponytail_vendor.py](../gridline/hooks/update_ponytail_vendor.py)

## Behavior

The work-group menu resolves project hooks against the live terminal folder when available, otherwise the saved project folder. The installer uses the containing Git root when there is one. It merges Gridline's hook entries into project `.codex/hooks.json` while retaining other hooks, and rejects malformed configuration or an unmarked Gridline-managed hook directory rather than replacing it.

Ponytail project setup and Codex compaction logging are separate actions. Compaction hook records omit prompt, transcript, and working-directory fields and are written only while the paired Gridline Debug view is active. The shared Ponytail source updater pulls only in its isolated vendor checkout; it does not pull Gridline's repository.

See the [Gridline Debug index](../gridline_debug/INDEX.md) for event names and log inspection. Keep provider hook adapters and project setup in `gridline/hooks/`, not in template views.

Read the [owning feature guide](../gridline/hooks/project-hooks.md) for its current checkpoint.

## Checkpoint

- [x] The current feature behavior and code paths are mapped.
- [ ] Recheck this page when its owning guide or implementation changes.
