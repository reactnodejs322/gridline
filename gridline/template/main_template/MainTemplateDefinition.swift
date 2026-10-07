import SwiftUI

/// Visual definition for the default template. Keep these design tokens with
/// the skin they describe so alternate templates can define their own.
extension GridlineTemplate {
    static let mainTemplatePalette = Palette(
        canvas: Color(red: 0.055, green: 0.06, blue: 0.07),
        toolbar: Color(red: 0.075, green: 0.08, blue: 0.09),
        surface: Color(red: 0.10, green: 0.105, blue: 0.115),
        elevatedSurface: Color(red: 0.075, green: 0.085, blue: 0.10),
        controlSurface: Color.black.opacity(0.28),
        accent: .mint,
        primaryText: Color(red: 0.9, green: 0.91, blue: 0.92),
        border: Color.white.opacity(0.1),
        groupHeader: Color.white.opacity(0.035),
        terminalHeader: Color(red: 0.12, green: 0.125, blue: 0.135),
        terminalCanvas: Color(red: 0.035, green: 0.04, blue: 0.045),
        terminalBorder: Color.white.opacity(0.09),
        groupIndicator: Color(red: 0.68, green: 0.86, blue: 0.48),
        folderAccent: Color(red: 0.65, green: 0.78, blue: 0.56)
    )

    static let mainTemplate = GridlineTemplate(
        id: "main_template",
        name: "Main",
        palette: mainTemplatePalette,
        makeWorkGroupCard: { context in
            AnyView(MainTemplateWorkGroupCard(
                group: context.group,
                groupSessions: context.groupSessions,
                template: context.template,
                workspace: context.workspace,
                editingGroup: context.editingGroup,
                groupDraft: context.groupDraft,
                editingSession: context.editingSession,
                sessionDraft: context.sessionDraft
            ))
        },
        makeUsageStatusView: { snapshot, codexUsage in
            AnyView(MainTemplateUsageStatusView(
                snapshot: snapshot,
                codexUsage: codexUsage,
                palette: GridlineTemplate.mainTemplatePalette
            ))
        }
    )
}
