# Swift code hygiene and LLM navigation

## Where this lives in code

- [Package.swift](../gridline/Package.swift)
- [Workspace.swift](../gridline/Sources/Gridline/Workspace.swift)
- [GridlineCodeContext.swift](../gridline_debug/Inspector/Sources/MyLLMDebug/GridlineCodeContext.swift)

## Swift code hygiene and LLM navigation

Use this chapter when changing Swift code. Start with the relevant row in the source map below, search for the exact type or behavior with `rg`, then read the containing file and its direct callers. Keep edits local to the owning layer and update the source map when a type moves.

### References

- [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/) — names should be clear at the call site, and documentation should explain non-obvious behavior.
- [Swift Protobuf style guide](https://github.com/apple/swift-protobuf/blob/main/Documentation/STYLE_GUIDELINES.md) — useful conventions for file/type organization, access control, and comments.
- [John Sundell: Encapsulating SwiftUI view styles](https://www.swiftbysundell.com/articles/encapsulating-swiftui-view-styles) — a design reference for keeping repeated SwiftUI presentation reusable and distinct from view behavior.

These are references, not a requirement to copy another project's architecture. Apply the ideas in ways that fit Gridline's existing layers and stable behavior.

### Repository conventions

- Prefer one primary type per file when it has an independent responsibility or is a likely edit target. Keep small, tightly coupled private SwiftUI helpers beside their owning view.
- Name files after their primary type or responsibility. Put shared app behavior in `gridline/Sources/Gridline/`, template presentation in `gridline/template/<template_id>/`, and inspector behavior in `gridline_debug/Inspector/Sources/MyLLMDebug/`.
- Keep provider parsing, process detection, persistence, and calculations out of SwiftUI views. Views present typed state and call shared actions; template-specific layout belongs in its template folder.
- Keep implementation details `private` unless another type or file needs them. Prefer named helpers to deeply nested conditional expressions, and document surprising behavior or non-obvious constraints.
- `gridline/Package.swift` lists Gridline Swift sources explicitly. Add every new app or template Swift file there. The inspector target discovers source files under its target path.
- Build the relevant app after Swift changes (`swift build` from its package, or use `./start.sh` when the main hot-reload pair is already intended to run). A successful app rebuild restarts that app and ends its live terminal processes. Do not add tests or run test suites unless requested.
- No Swift formatter or linter is configured in this repository. Keep edits consistent with nearby code and check whitespace with `git diff --check`; do not claim a formatter pass unless one is installed and actually run.

### Swift file map

| Area | Main type or responsibility | File | Search from repository root |
| --- | --- | --- | --- |
| App entry and menu commands | `GridlineApp` | `gridline/Sources/Gridline/GridlineApp.swift` | `rg -n 'struct GridlineApp|commands|CommandGroup' gridline/Sources/Gridline` |
| Workspace data, terminal process, and workspace actions | `SavedGroup`, `SavedSession`, `WorkspaceSnapshot`, `TerminalSession`, `WorkspaceStore` | `gridline/Sources/Gridline/Workspace.swift` | `rg -n 'struct SavedGroup|class TerminalSession|class WorkspaceStore|func runDirectoryCommand' gridline/Sources/Gridline/Workspace.swift` |
| Workspace and terminal presentation | `WorkspaceView`, directory prompt, terminal pane, transcription and skill UI | `gridline/Sources/Gridline/Workspace.swift` | `rg -n 'struct WorkspaceView|struct TerminalPane|DirectoryCommandField|SkillScriptDropdownView' gridline/Sources/Gridline/Workspace.swift` |
| Codex project hook installation and hook state view | `CodexHooksPanel`, `CodexHooksPanelModel` | `gridline/Sources/Gridline/CodexHooks.swift` | `rg -n 'CodexHooksPanel|CodexHooksPanelModel' gridline/Sources/Gridline/CodexHooks.swift` |
| Live voice capture and transcription | `AudioTranscriptionModel` | `gridline/Sources/Gridline/Workspace.swift` | `rg -n 'class AudioTranscriptionModel|AudioTranscriptionModel' gridline/Sources/Gridline` |
| Voice todo model and presentation | `VoiceTodoModel`, `VoiceTodoModalView` | `gridline/Sources/Gridline/VoiceTodo.swift` | `rg -n 'class VoiceTodoModel|struct VoiceTodoModalView|VoiceTodoFormatting' gridline/Sources/Gridline/VoiceTodo.swift` |
| Provider allowance and process usage state | `CodexUsageStatus`, `ProviderUsageStatus`, typed snapshots | `gridline/Sources/Gridline/ProviderUsageService.swift` | `rg -n 'class CodexUsageStatus|class ProviderUsageStatus|struct ProviderUsageSnapshot|refreshProcessStatus' gridline/Sources/Gridline/ProviderUsageService.swift` |
| Semantic event names and logging | `DebugEvents` | `gridline/Sources/Gridline/DebugEvents.swift` | `rg -n 'enum DebugEvents|static func' gridline/Sources/Gridline/DebugEvents.swift` |
| Template types, context, and selection | `GridlineTemplate`, `GridlineWorkGroupCardContext`, catalog/store | `gridline/template/TemplateCatalog.swift` | `rg -n 'struct GridlineTemplate|struct GridlineWorkGroupCardContext|enum GridlineTemplateCatalog|class GridlineTemplateStore' gridline/template/TemplateCatalog.swift` |
| Main template factories | `makeWorkGroupCard`, `makeUsageStatusView` | `gridline/template/main_template/MainTemplateDefinition.swift` | `rg -n 'extension GridlineTemplate|makeWorkGroupCard|makeUsageStatusView' gridline/template/main_template` |
| Main template workgroup and terminal tile UI | `MainTemplateWorkGroupCard`, private terminal card | `gridline/template/main_template/MainTemplateWorkGroupCard.swift` | `rg -n 'struct MainTemplateWorkGroupCard|struct MainTemplateTerminalCard' gridline/template/main_template` |
| Main template usage meter | `MainTemplateUsageStatusView` | `gridline/template/main_template/MainTemplateUsageStatusView.swift` | `rg -n 'struct MainTemplateUsageStatusView|UsageRefreshSettingsPopover' gridline/template/main_template` |
| Main template reusable dropdown shell | `MainTemplateDropdownPanel` | `gridline/template/main_template/MainTemplateDropdownPanel.swift` | `rg -n 'struct MainTemplateDropdownPanel' gridline/template/main_template` |
| Main template reusable dropdown row | `MainTemplateDropdownActionRow` | `gridline/template/main_template/MainTemplateDropdownActionRow.swift` | `rg -n 'struct MainTemplateDropdownActionRow' gridline/template/main_template` |
| Inspector element/event model | `DebugElement`, `InspectorEvent` | `gridline_debug/Inspector/Sources/MyLLMDebug/DebugElement.swift` | `rg -n 'struct DebugElement|struct InspectorEvent' gridline_debug/Inspector/Sources/MyLLMDebug` |
| Inspector state and report writing | `InspectorStore` | `gridline_debug/Inspector/Sources/MyLLMDebug/InspectorStore.swift` | `rg -n 'class InspectorStore|func copyElementContext|func saveReport' gridline_debug/Inspector/Sources/MyLLMDebug` |
| Accessibility-to-source context for LLMs | `GridlineCodeContext` | `gridline_debug/Inspector/Sources/MyLLMDebug/GridlineCodeContext.swift` | `rg -n 'enum GridlineCodeContext|sourcePath\(|makeCopyText' gridline_debug/Inspector/Sources/MyLLMDebug` |
| Inspector window | `InspectorView` | `gridline_debug/Inspector/Sources/MyLLMDebug/InspectorView.swift` | `rg -n 'struct InspectorView' gridline_debug/Inspector/Sources/MyLLMDebug` |
| Accessibility change observer | `AXChangeWatcher` | `gridline_debug/Inspector/Sources/MyLLMDebug/AXChangeWatcher.swift` | `rg -n 'class AXChangeWatcher' gridline_debug/Inspector/Sources/MyLLMDebug` |
| Hover outline overlay | `HoverHighlight` | `gridline_debug/Inspector/Sources/MyLLMDebug/HoverHighlight.swift` | `rg -n 'class HoverHighlight|class HoverBorderView' gridline_debug/Inspector/Sources/MyLLMDebug` |
| Inspector app entry | `MyLLMDebugApp` | `gridline_debug/Inspector/Sources/MyLLMDebug/MyLLMDebugApp.swift` | `rg -n 'struct MyLLMDebugApp' gridline_debug/Inspector/Sources/MyLLMDebug` |
| Swift icon tools | Debug and version app icon generators | `gridline/tools/` | `rg -n 'NSImage|CGContext|write' gridline/tools --glob '*.swift'` |
| SwiftPM source inclusion | Gridline package manifest | `gridline/Package.swift` | `rg -n 'sources:|resources:|template/' gridline/Package.swift` |
| Inspector SwiftPM configuration | Inspector package manifest | `gridline_debug/Inspector/Package.swift` | `rg -n 'executableTarget|platforms|products' gridline_debug/Inspector/Package.swift` |

### Audit notes

- The repository's Swift sources were reviewed for navigation, naming, access control, force unwraps, and obvious asynchronous state hazards. A provider usage refresh could previously restore a stale cost snapshot after an asynchronous process scan; the scan now preserves the latest cost fields when applying its result.
- The fixed Accessibility Settings URL now uses optional handling instead of a force unwrap. `fatalError` in `HoverHighlight`'s coder initializer is intentional because that AppKit view is created programmatically.
- `GridlineCodeContext.searchTerm(...)` states the inspector's source-search priority as ordered checks; keep this mapping explicit so copied LLM context points to a useful symbol instead of relying on a nested conditional.
- `Workspace.swift` and `VoiceTodo.swift` contain multiple related model and view types. Use the map above to jump directly to the owning type; split these files only when changing a cohesive area and preserve package inclusion, Accessibility identifiers, persistence, and behavior.

## Checkpoint

- [x] The original AGENTS.md guidance in the sections above is preserved here.
- [ ] Recheck paths and behavior when the owning implementation changes.
