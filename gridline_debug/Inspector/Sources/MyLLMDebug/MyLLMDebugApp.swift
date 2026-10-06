import SwiftUI
import AppKit

@main
struct MyLLMDebugApp: App {
    @StateObject private var inspector = InspectorStore()

    init() {
        if let iconURL = Bundle.main.url(forResource: "MyLLMDebug", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApplication.shared.applicationIconImage = icon
        }
    }

    var body: some Scene {
        WindowGroup {
            InspectorView()
                .environmentObject(inspector)
                .frame(minWidth: 960, minHeight: 680)
                .preferredColorScheme(.dark)
                .task {
                    inspector.refreshPermissionState()
                    if inspector.isTrusted { inspector.startInspecting() }
                    while !Task.isCancelled {
                        inspector.refreshLogs()
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                    }
                }
        }
        .windowStyle(.titleBar)
    }
}
