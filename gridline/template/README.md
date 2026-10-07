# Gridline template system

This directory holds Gridline's selectable UI skins. A template decides how shared workspace information is presented; it does not own a second copy of work groups, terminal sessions, process state, or persistence. Read this before changing the template architecture or adding a skin.

## Start here

| If you are changing… | Read or edit… |
| --- | --- |
| Template registration, shared palette/context types, or selection persistence | `TemplateCatalog.swift` |
| The default Gridline skin | `main_template/README.md`, then the Swift file named there |
| How the active skin is inserted into the workspace | `gridline/Sources/Gridline/Workspace.swift` → `WorkspaceView.template`, `groupCard(_:)`, and the active template Accessibility root |
| Accessibility-to-source lookup and UI debug context | `gridline_debug/INDEX.md`, then `gridline_debug/Inspector/Sources/MyLLMDebug/GridlineCodeContext.swift` |
| Build and live-reload inclusion | `gridline/Package.swift` and `gridline_debug/watch-build.sh` |

## Current architecture

- `GridlineTemplate` is the skin descriptor. It contains an ID, display name, `Palette`, and factories for the work-group card and usage-status component.
- `GridlineTemplate.Palette` contains visual colors used by the skin. Keep skin-specific visual values beside the skin rather than adding another parallel styling system.
- `GridlineWorkGroupCardContext` is the input boundary for the group-card view: the saved group, that group's live sessions, the selected template, the shared `WorkspaceStore`, and the group/session editing bindings.
- `MainTemplateUsageStatusView` receives a typed `ProviderUsageSnapshot` and shared `CodexUsageStatus`; it renders status data without reading provider files or running scripts itself.
- `GridlineTemplateCatalog.all` is the authoritative list of available skins. `template(for:)` safely falls back to `main_template` for an unknown or stale ID.
- `GridlineTemplateStore` owns selected skin preference. It reads and writes `gridline.template.selectedID` in `UserDefaults`, validates selection against the catalog, and records `template.selected` with `gridline.template.option.<id>`.
- `WorkspaceView` gets `activeTemplate` from the shared store, calls `template.makeWorkGroupCard(...)` for each group, and calls `template.makeUsageStatusView(...)` for the top usage status. The rendered workspace root is identified as `gridline.template.active.<template_id>`.
- `ProviderUsageStatus` in `gridline/Sources/Gridline/ProviderUsageService.swift` reads bundled JSON tools and process names into reusable snapshots. `WorkspaceView` passes those snapshots to the selected template's usage-status factory.
- `main_template/` is the only registered skin today. The Swift files are explicitly listed in `gridline/Package.swift`; add new Swift files there or the app target will not compile them. The watcher also needs to observe the template folder; check `gridline_debug/watch-build.sh` if its watch paths change.

## Ownership boundary

Templates own SwiftUI presentation: view composition within their assigned surface, palette, spacing, typography, and the visual arrangement of controls. They call the existing shared actions and models for behavior.

Shared Gridline code remains the source of truth for work-group and terminal data, terminal process lifecycle, title updates, actions, and saved workspace state. For example, a template renames a terminal by calling `TerminalSession.rename(_:)`; that shared model notifies `WorkspaceStore.changed()`, which persists to `~/Library/Application Support/Gridline/workspace.json`. Never keep a template-local label, group, or session copy.

Today the template factory replaces the work-group card surface. The app shell, toolbar, tabs, skill-script UI, voice-todo UI, and other workspace orchestration still live in `WorkspaceView` and related shared views. Do not assume that every part of the app is already skin-driven. If a redesign needs a new surface to vary by skin, add a clear factory/context boundary for that surface while leaving its data and actions in shared Gridline code.

## Adding or changing a skin

1. Read `main_template/README.md` and inspect its implementation before using it as the behavioral reference.
2. Create `gridline/template/<template_id>/` for the skin's SwiftUI views, visual definition, assets, and concise implementation notes.
3. Define the skin's palette and view factories as a `GridlineTemplate`. Use the existing shared context types when the view needs group/session state or editing bindings.
4. Register the descriptor in `GridlineTemplateCatalog.all`. Keep IDs stable: saved selection uses the ID, so changing an existing ID makes the old preference fall back to `main_template`.
5. Add each Swift source file explicitly to the app target in `gridline/Package.swift`. Keep the template documentation resources listed there if package resource declarations need updating.
6. Preserve stable Accessibility IDs for interactive controls and identify the active template root as `gridline.template.active.<template_id>`. A template root/container ID does not replace child control IDs.
7. Keep semantic events on the shared action path. Template selection already records `template.selected`; new shared workflow actions should retain their existing event names.
8. Update `gridline_debug/INDEX.md` when the source map or Accessibility-to-source lookup changes.

Do not duplicate a workflow just to change its appearance. If a new visual arrangement needs new inputs, extend the context with the smallest shared state/action interface needed, then have each skin use that same interface.
