# Main template

`main_template` is the default Gridline skin and the reference implementation for template-owned UI. It controls the current work-group and terminal-card presentation. Shared workspace and terminal behavior stays in the main Gridline models and stores.

## Files

| File | Responsibility |
| --- | --- |
| `MainTemplateDefinition.swift` | Defines the stable ID `main_template`, display name `Main`, palette values, and factories for the work-group card and top usage status. |
| `MainTemplateWorkGroupCard.swift` | Defines the colored work-group terminal tile, compact label row, and terminal-action dropdown. |
| `MainTemplateUsageStatusView.swift` | Renders separate cyan weekly provider meters from shared snapshots; ChatGPT uses the reported allowance and Claude uses its rolling seven-day estimate. Its ChatGPT dropdown preserves the meter and offers fetching controls. |
| `MainTemplateDropdownPanel.swift` | Reusable palette-aware dropdown panel shell. Skill scripts, workspace controls, directory prompt, work-group actions, and usage settings share its bordered surface. |
| `MainTemplateDropdownActionRow.swift` | Reusable hoverable action row for dropdown panels, with a title, optional subtitle, icon, stable Accessibility ID, and action. |
| `../TemplateCatalog.swift` | Defines the descriptor, palette/context contracts, catalog, and selected-template preference. Registration happens in `GridlineTemplateCatalog.all`. |
| `../../Sources/Gridline/Workspace.swift` | Owns the workspace shell, constructs `GridlineWorkGroupCardContext`, supplies editing bindings, and owns shared workspace/session behavior. |

## Rendering and state flow

1. `GridlineTemplateStore.activeTemplate` resolves the saved selection through `GridlineTemplateCatalog`.
2. `WorkspaceView.groupCard(_:)` packages the group, its live `TerminalSession` objects, `WorkspaceStore`, and editing bindings into `GridlineWorkGroupCardContext`.
3. The active template's `makeWorkGroupCard` factory builds `MainTemplateWorkGroupCard` and passes that shared context through.
4. The card uses the palette for visual styling and calls the shared store/model for user actions. The view does not create or persist duplicate group/session data.
5. `MainTemplateUsageStatusView` renders the two weekly meters. ChatGPT's percentage is the reported weekly plan allowance; its dollar figure is that percentage of the stated $20 plan price. Claude's weekly API-equivalent estimate is compared with a $20 reference. Neither is a subscription charge; provider parsing and process detection remain in the shared Gridline service.

The current main template renders a tight three-column grid of work-group terminal tiles with stable, distinct accent borders. Each tile puts the work-group name and terminal label in one compact header and fills the remaining area with its shared terminal pane. Group collapse, folder selection, session creation, terminal label editing, font zoom, and close actions remain in the tile's shared-style action dropdown or inline label editor. The shared terminal-height resize handle remains attached to each pane. An empty group can start a Codex session.

## Shared data and behavior rules

- Group operations call `WorkspaceStore` (`toggle`, `renameGroup`, `chooseDirectory`, `addSession`, and `closeGroup`).
- Terminal label edits call `TerminalSession.rename(_:)`. That shared model updates title-following state and causes `WorkspaceStore.changed()` to save the workspace metadata. The saved value belongs to the session in `workspace.json`, not to this view.
- Font zoom calls `TerminalSession.zoomOut()` / `zoomIn()`. Pane resizing calls `WorkspaceStore.resizeTerminal(...)` through `TerminalHeightResizeHandle`. Keep these paths when restyling the controls.
- `TerminalPane` remains the shared terminal implementation. A skin may change its surrounding chrome, but should not create a separate terminal/process implementation to change presentation.
- Group and session editing IDs/drafts are supplied by the workspace through bindings. Keep their ownership shared unless the app architecture is deliberately changed for every skin together.

## Accessibility and Gridline Debug

Keep stable identifiers on the controls while changing layout or appearance. The group card and header use `gridline.group.card.<group UUID>` and `gridline.group.header.<group UUID>`. Child controls include `gridline.group.toggle.<group UUID>`, `gridline.group.name.<group UUID>`, `gridline.group.folder.<group UUID>`, `gridline.group.addSession.<group UUID>`, `gridline.group.addCodex.<group UUID>`, and `gridline.group.close.<group UUID>` (some controls appear only in the relevant state).

Terminal controls use `gridline.session.label.<session UUID>`, `gridline.session.zoomOut.<session UUID>`, `gridline.session.fontSize.<session UUID>`, `gridline.session.zoomIn.<session UUID>`, and `gridline.session.close.<session UUID>`. These remain available from each tile's shared-style action dropdown or label editor. Preserve useful accessibility labels and the IDs on the actual interactive element. The active workspace template root is set in `WorkspaceView` as `gridline.template.active.<template_id>`.

The maintained identifier-to-source map is `gridline_debug/INDEX.md`; lookup behavior and copied LLM context are in `gridline_debug/Inspector/Sources/MyLLMDebug/GridlineCodeContext.swift`. Update those maps if identifiers or their owning source files change so Gridline Debug still points the next LLM to the right code.

## Safe redesign checklist

- Keep `main_template` as the default skin unless the product explicitly changes that decision.
- Keep the `main_template` ID stable so saved template selection remains valid.
- Change the SwiftUI composition and palette here; route actions and values through the shared context, `WorkspaceStore`, and `TerminalSession`.
- Preserve stable Accessibility IDs and semantic action behavior.
- Add new Swift files to `gridline/Package.swift`; confirm `gridline_debug/watch-build.sh` watches the template sources.
- Update this guide, `gridline/template/README.md`, and `gridline_debug/INDEX.md` when responsibilities or source paths change.
