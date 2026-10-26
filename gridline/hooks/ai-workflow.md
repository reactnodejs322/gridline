# AI workflow

## Where this lives in code

- [`CodexHooks.swift`](../Sources/Gridline/CodexHooks.swift)
- [`MainTemplateWorkGroupCard.swift`](../template/main_template/MainTemplateWorkGroupCard.swift)
- [`install_project_hooks.py`](install_project_hooks.py)
- [`agent_workflow.md`](agent_workflow.md)
- [`fix_ai_workflow.md`](fix_ai_workflow.md)
- [`build-app.sh`](../build-app.sh)

## Behavior

The work-group **AI workflow…** action opens a disposable Codex terminal at the resolved project root and stages the complete selected guide. Closing the modal terminates that terminal; it is not saved in `workspace.json`. The guide is bundled with Gridline and is not copied into the project's `.codex/` directory.

Both guides require a proposal and explicit user approval before project Markdown edits. They preserve project-specific rules and the existing linked chapter map, then route human wording through a separate keyword table to focused Markdown guides and verified code paths.

The installer checks whether the bundled guides are available and reports project conflicts. A root `doc/` directory, or an unmanaged `docs/` directory without the workflow marker, disables the Create action. This repository now uses `docs/` for feature documents; the Create action will report that conflict for this repository until the installer policy or managed marker changes. Fix remains available.

## Checkpoint

- [x] Temporary terminal lifecycle, guide bundling, and approval boundary are mapped.
- [x] The root `docs/` conflict is recorded so documentation cleanup does not disable Create for this project.
- [ ] Recheck if the modal lifecycle, installer conflict check, or bundled guide names change.
