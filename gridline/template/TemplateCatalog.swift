import SwiftUI

/// A visual skin for Gridline. Templates own appearance tokens and the
/// work-group UI factory; shared models/actions keep state consistent.
struct GridlineTemplate: Identifiable {
    struct Palette {
        let canvas: Color
        let toolbar: Color
        let surface: Color
        let elevatedSurface: Color
        let controlSurface: Color
        let accent: Color
        let primaryText: Color
        let border: Color
        let groupHeader: Color
        let terminalHeader: Color
        let terminalCanvas: Color
        let terminalBorder: Color
        let groupIndicator: Color
        let folderAccent: Color
    }

    let id: String
    let name: String
    let palette: Palette
    let makeWorkGroupCard: (GridlineWorkGroupCardContext) -> AnyView
    let makeUsageStatusView: (ProviderUsageSnapshot, CodexUsageStatus) -> AnyView
}

/// Shared model and interaction state provided to each skin's work-group UI.
/// A template controls the view while actions continue through the same store.
struct GridlineWorkGroupCardContext {
    let group: SavedGroup
    let groupSessions: [TerminalSession]
    let template: GridlineTemplate
    let workspace: WorkspaceStore
    let editingGroup: Binding<UUID?>
    let groupDraft: Binding<String>
    let editingSession: Binding<UUID?>
    let sessionDraft: Binding<String>
}

/// Central catalog for available skins. Add variants here while keeping
/// workflow implementations in their shared feature views.
enum GridlineTemplateCatalog {
    static let all: [GridlineTemplate] = [.mainTemplate]

    static func template(for id: String) -> GridlineTemplate {
        all.first(where: { $0.id == id }) ?? .mainTemplate
    }
}

@MainActor
final class GridlineTemplateStore: ObservableObject {
    private static let selectionKey = "gridline.template.selectedID"

    @Published private(set) var selectedTemplateID: String {
        didSet { UserDefaults.standard.set(selectedTemplateID, forKey: Self.selectionKey) }
    }

    var activeTemplate: GridlineTemplate {
        GridlineTemplateCatalog.template(for: selectedTemplateID)
    }

    init() {
        let savedID = UserDefaults.standard.string(forKey: Self.selectionKey) ?? GridlineTemplate.mainTemplate.id
        selectedTemplateID = GridlineTemplateCatalog.template(for: savedID).id
    }

    func selectTemplate(id: String) {
        guard GridlineTemplateCatalog.all.contains(where: { $0.id == id }) else { return }
        selectedTemplateID = id
        DebugEvents.record("template.selected", element: "gridline.template.option.\(id)", details: ["templateID": id])
    }
}
