# Templates and dropdowns

## Where this lives in code

- [TemplateCatalog.swift](../gridline/template/TemplateCatalog.swift)
- [MainTemplateDefinition.swift](../gridline/template/main_template/MainTemplateDefinition.swift)
- [MainTemplateWorkGroupCard.swift](../gridline/template/main_template/MainTemplateWorkGroupCard.swift)
- [MainTemplateDropdownPanel.swift](../gridline/template/main_template/MainTemplateDropdownPanel.swift)
- [Workspace.swift](../gridline/Sources/Gridline/Workspace.swift)

## UI templates and skins

- Template source code and skin folders: `gridline/template/`. `gridline/Package.swift` explicitly includes each template Swift file in the Gridline app target; `gridline_debug/watch-build.sh` watches this folder for reloads.
- Skin-specific assets and notes: `gridline/template/<template_id>/`; current skin: `gridline/template/main_template/`.
- `main_template` is the default skin and preserves the current Gridline appearance.
- A template owns its SwiftUI presentation components: palette, layout, spacing, labels, and controls. Shared data and actions remain in Gridline models/stores; template controls call those shared paths rather than keeping separate copies.
- Put reusable presentation components beside the skin that owns their appearance, in `gridline/template/<template_id>/`; no extra component folder is needed unless a template grows enough components to warrant one. For the main skin, `gridline/template/main_template/MainTemplateDropdownPanel.swift` is the shared palette-aware dropdown surface and `MainTemplateDropdownActionRow.swift` is its matching action row. Use these for new dropdown/popover panels and action items so their title, border, surface, hover state, spacing, and shadow stay consistent. Search with `rg -n 'MainTemplateDropdownPanel|MainTemplateDropdownActionRow' gridline/template gridline/Sources/Gridline` before creating another dropdown style.
- `GridlineTemplate.makeWorkGroupCard` selects each skin's card component; `makeUsageStatusView` selects its status presentation. Both receive shared models/snapshots rather than owning duplicate data.
- Terminal labels are per-session data in `SavedSession` and persist to `~/Library/Application Support/Gridline/workspace.json`. Every template must edit them through `TerminalSession.rename(_:)`, which saves through `WorkspaceStore.changed()`.
- The template owns UI components, including how each terminal label is presented and edited. Gridline's shared `TerminalSession` and `WorkspaceStore` own the label value, terminal-title behavior, and persistence; never create a template-local copy of terminal data.
- The selected template ID is persisted in UserDefaults. Add future selectable skins to `GridlineTemplateCatalog`; build the template dropdown from that catalog instead of hardcoding menu items.
- Add a distinct template view/composition only when a skin needs a different arrangement or additional presentation. Pass shared feature actions and state into it so existing workflows remain consistent.
- Keep stable Accessibility identifiers attached to shared controls even when a template changes their visual presentation.
- Make each rendered template root an Accessibility container labeled with its template ID and identified as `gridline.template.active.<template_id>`. Give each interactive template control its own stable identifier; do not make the root identifier replace child control IDs.
- Template selector controls use `gridline.template.selector` and `gridline.template.option.<template_id>`. Record `template.selected` with the option identifier so Gridline Debug can correlate a selection.

### Main template dropdown code flow

Use this path when changing a dropdown's appearance, open/close behavior, or actions. `MainTemplateDropdownPanel` and `MainTemplateDropdownActionRow` are presentation components; they do not own workspace or provider state.

| UI / entry point | State and reusable view | Action destination |
| --- | --- | --- |
| Workspace hamburger | [`WorkspaceView.topBar`](../gridline/Sources/Gridline/Workspace.swift) owns `isWorkspaceActionsExpanded`; it presents `MainTemplateDropdownPanel` with shared action rows. | Rows call `WorkspaceStore`, change the selected app tab, or open the directory/skill-script panel. Grid column changes go through `WorkspaceStore.setColumns(_:)`. |
| Skill scripts | `WorkspaceView.topBar` opens `SkillScriptDropdownView` in `Workspace.swift`; that view uses the shared panel and action rows with the active template palette. | Closures launch audio transcription or open Voice todo; implementations remain in their existing skill/workspace paths. |
| Work-group ellipsis | [`MainTemplateWorkGroupCard`](../gridline/template/main_template/MainTemplateWorkGroupCard.swift) owns `showingActionsDropdown` and presents the shared panel. | Folder, group, and session actions call `WorkspaceStore` or `TerminalSession`; retain their existing Accessibility IDs. |
| ChatGPT usage meter | [`MainTemplateUsageStatusView`](../gridline/template/main_template/MainTemplateUsageStatusView.swift) keeps the meter visible and opens the shared panel for refresh preferences. | Bindings call `CodexUsageStatus`; the usage monitor and saved settings live in [`ProviderUsageService.swift`](../gridline/Sources/Gridline/ProviderUsageService.swift). |
| Directory command | `WorkspaceView.directoryCommandPopover` uses the shared panel around the existing inline `cd`/`pwd`/`ls` field. | `WorkspaceView.runDirectoryCommand()` delegates to `WorkspaceStore`; preserve its validation and completion behavior. |

To trace a new dropdown, start at its trigger and `@State` in the table, follow its `.popover` to the shared panel, then follow each action closure to the named store/service. Do not move action logic into the reusable panel or duplicate state there.

## Checkpoint

- [x] The original AGENTS.md guidance in the sections above is preserved here.
- [ ] Recheck paths and behavior when the owning implementation changes.
