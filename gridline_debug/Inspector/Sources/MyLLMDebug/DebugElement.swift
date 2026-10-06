import ApplicationServices
import AppKit
import Foundation

struct DebugElement: Codable, Identifiable, Equatable {
    static var targetBundleID: String {
        Bundle.main.object(forInfoDictionaryKey: "GridlineTargetBundleID") as? String ?? "local.gridline.terminal"
    }
    static var targetProcessIdentifier: pid_t? {
        let matches = NSRunningApplication.runningApplications(withBundleIdentifier: targetBundleID)
            .filter { !$0.isTerminated }
        // Each Gridline copy has its own bundle ID. Refuse an ambiguous match
        // instead of attaching this inspector to an arbitrary process.
        guard matches.count == 1, let target = matches.first else { return nil }
        if let path = Bundle.main.object(forInfoDictionaryKey: "GridlineTargetPIDFile") as? String {
            let pidText = String(target.processIdentifier)
            let current = try? String(contentsOfFile: path, encoding: .utf8)
            if current?.trimmingCharacters(in: .whitespacesAndNewlines) != pidText {
                try? FileManager.default.createDirectory(
                    at: URL(fileURLWithPath: path).deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try? Data("\(pidText)\n".utf8).write(to: URL(fileURLWithPath: path), options: .atomic)
            }
        }
        return target.processIdentifier
    }
    var id: String { "\(pid):\(role):\(identifier):\(title)" }
    let app: String
    let bundleID: String
    let pid: Int32
    let role: String
    let subrole: String
    let title: String
    let identifier: String
    let help: String
    let hierarchy: [String]
    let axFrame: CGRect

    var searchHint: String {
        [identifier, title, role].filter { !$0.isEmpty }.joined(separator: " ")
    }

    @MainActor
    static func currentAXPoint() -> CGPoint {
        axPoint(for: NSEvent.mouseLocation)
    }

    @MainActor
    var highlightFrame: CGRect? {
        guard axFrame.width > 1, axFrame.height > 1,
              let primary = NSScreen.screens.first(where: { $0.frame.origin == .zero }) ?? NSScreen.main else { return nil }
        return CGRect(
            x: primary.frame.minX + axFrame.minX,
            y: primary.frame.maxY - axFrame.maxY,
            width: axFrame.width,
            height: axFrame.height
        )
    }

    static func atPoint(_ point: CGPoint) -> DebugElement? {
        let system = AXUIElementCreateSystemWide()
        var raw: AXUIElement?
        guard AXUIElementCopyElementAtPosition(system, Float(point.x), Float(point.y), &raw) == .success,
              let raw, let element = snapshot(raw) else { return nil }
        guard element.pid != ProcessInfo.processInfo.processIdentifier,
              let targetPID = targetProcessIdentifier,
              element.pid == targetPID,
              element.bundleID == targetBundleID else { return nil }
        return element
    }

    private static func snapshot(_ element: AXUIElement) -> DebugElement? {
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success else { return nil }
        let role = text(element, kAXRoleAttribute as String) ?? "Unknown"
        let title = text(element, kAXTitleAttribute as String) ?? text(element, "AXLabel") ?? ""
        let identifier = text(element, "AXIdentifier") ?? ""
        let subrole = text(element, kAXSubroleAttribute as String) ?? ""
        let help = text(element, kAXHelpAttribute as String) ?? ""
        let bounds = frame(element) ?? .zero
        let app = NSRunningApplication(processIdentifier: pid)
        return DebugElement(
            app: app?.localizedName ?? "Process \(pid)",
            bundleID: app?.bundleIdentifier ?? "",
            pid: pid,
            role: role,
            subrole: subrole,
            title: title,
            identifier: identifier,
            help: help,
            hierarchy: parentTrail(from: element),
            axFrame: bounds
        )
    }

    private static func frame(_ element: AXUIElement) -> CGRect? {
        var rawPosition: CFTypeRef?
        var rawSize: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &rawPosition) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &rawSize) == .success,
              let rawPosition, let rawSize,
              CFGetTypeID(rawPosition) == AXValueGetTypeID(),
              CFGetTypeID(rawSize) == AXValueGetTypeID() else { return nil }
        let positionValue = unsafeBitCast(rawPosition, to: AXValue.self)
        let sizeValue = unsafeBitCast(rawSize, to: AXValue.self)
        var origin = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue, .cgPoint, &origin),
              AXValueGetValue(sizeValue, .cgSize, &size),
              origin.x.isFinite, origin.y.isFinite,
              size.width.isFinite, size.height.isFinite else { return nil }
        return CGRect(origin: origin, size: size)
    }

    private static func text(_ element: AXUIElement, _ name: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success,
              let value else { return nil }
        return value as? String
    }

    private static func parentTrail(from element: AXUIElement) -> [String] {
        var trail: [String] = []
        var current = element
        for _ in 0..<7 {
            let role = text(current, kAXRoleAttribute as String) ?? "?"
            let title = text(current, kAXTitleAttribute as String) ?? text(current, "AXLabel") ?? text(current, "AXIdentifier") ?? ""
            trail.append(title.isEmpty ? role : "\(role): \(title)")
            var parent: CFTypeRef?
            guard AXUIElementCopyAttributeValue(current, kAXParentAttribute as CFString, &parent) == .success,
                  let parent, CFGetTypeID(parent) == AXUIElementGetTypeID() else { break }
            current = unsafeBitCast(parent, to: AXUIElement.self)
        }
        return trail.reversed()
    }

    @MainActor
    private static func axPoint(for point: CGPoint) -> CGPoint {
        let primary = NSScreen.screens.first { $0.frame.origin == .zero } ?? NSScreen.main
        return CGPoint(x: point.x, y: (primary?.frame.height ?? 0) - point.y)
    }
}

struct InspectorEvent: Codable, Identifiable, Equatable {
    let id: UUID
    let time: Date
    let kind: String
    let element: DebugElement
    let detail: String

    init(kind: String, element: DebugElement, detail: String) {
        id = UUID()
        time = Date()
        self.kind = kind
        self.element = element
        self.detail = detail
    }
}
