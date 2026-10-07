import SwiftUI
import AppKit

@main
struct GridlineApp: App {
    @StateObject private var workspace = WorkspaceStore()
    @StateObject private var templateStore = GridlineTemplateStore()

    init() {
        if let iconURL = Bundle.main.url(forResource: "Gridline", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApplication.shared.applicationIconImage = icon
        }
    }

    var body: some Scene {
        WindowGroup {
            WorkspaceView()
                .environmentObject(workspace)
                .environmentObject(templateStore)
                .frame(minWidth: 850, minHeight: 600)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(after: .appInfo) {
                Divider()
                Button("Expand All Workgroups") { workspace.expandAllWorkgroups() }
                    .accessibilityIdentifier("gridline.workgroups.expandAll")
                Button("Collapse All Workgroups") { workspace.collapseAllWorkgroups() }
                    .accessibilityIdentifier("gridline.workgroups.collapseAll")
            }
            CommandGroup(after: .newItem) {
                Button("New Codex Session") { workspace.addSession(kind: .codex) }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                Button("New Work Group") { workspace.addGroup() }
                    .keyboardShortcut("g", modifiers: [.command, .shift])
            }
        }
    }
}
