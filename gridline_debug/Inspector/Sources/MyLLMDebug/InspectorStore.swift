import AppKit
import ApplicationServices
import Combine
import Foundation

@MainActor
final class InspectorStore: ObservableObject {
    @Published var isTrusted = AXIsProcessTrusted()
    @Published var isInspecting = false
    @Published var hovered: DebugElement?
    @Published var pinned: DebugElement?
    @Published var selectionIsClick = false
    @Published var clicks: [InspectorEvent] = []
    @Published var appEvents: [String] = []
    @Published var copyStatus = ""
    @Published var buildStatus = "No build has been recorded yet."
    @Published var buildErrors = ""
    @Published var inspectionStatus = "Inspection is stopped."

    private var eventTap: CFMachPort?
    private var tapSource: CFRunLoopSource?
    private var changeWatcher: AXChangeWatcher?
    private var watchedPID: pid_t?
    private var lastHoverUpdate = Date.distantPast
    private var hoverGeneration = 0
    private var permissionTimer: Timer?
    private let hoverHighlight = HoverHighlight()

    init() {
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak store = self] in store?.refreshPermissionState() }
        }
    }

    static var root: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    var debugDirectory: URL { Self.root }
    var versionLabel: String? {
        let label = Bundle.main.object(forInfoDictionaryKey: "GridlineVersionLabel") as? String
        guard let label, label.hasPrefix("version_") else { return nil }
        return "Version \(label.dropFirst("version_".count))"
    }
    var targetProcessIdentifier: pid_t? { DebugElement.targetProcessIdentifier }
    var targetDisplayName: String {
        Bundle.main.object(forInfoDictionaryKey: "GridlineTargetName") as? String ?? "Gridline"
    }

    func requestPermission() {
        refreshPermissionState()
        if !isTrusted {
            inspectionStatus = "System Settings opened. Remove old Gridline Debug entries with −, add this Gridline Debug app with +, then enable it. Permission is checked automatically."
            openAccessibilitySettings()
        }
    }

    func openAccessibilitySettings() {
        if let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"),
           !NSWorkspace.shared.open(settingsURL),
           let fallback = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension") {
            NSWorkspace.shared.open(fallback)
        }
    }

    func refreshPermissionState() {
        let trusted = AXIsProcessTrusted()
        let permissionWasGranted = !isTrusted && trusted
        isTrusted = trusted
        if permissionWasGranted { startInspecting() }
    }

    func startInspecting() {
        guard eventTap == nil else { isInspecting = true; return }
        guard AXIsProcessTrusted() else {
            isTrusted = false
            inspectionStatus = "Accessibility permission is not active for this inspector process yet. Toggle it off and on, then use Check permission again."
            return
        }
        let mask = (1 << CGEventType.mouseMoved.rawValue)
            | (1 << CGEventType.leftMouseDown.rawValue)
            | (1 << CGEventType.rightMouseDown.rawValue)
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                let store = Unmanaged<InspectorStore>.fromOpaque(context).takeUnretainedValue()
                Task { @MainActor in store.receive(type) }
                return Unmanaged.passUnretained(event)
            },
            userInfo: pointer
        )
        guard let eventTap else {
            inspectionStatus = "Accessibility is allowed, but macOS refused the global pointer monitor. Check Privacy & Security → Input Monitoring too, then restart Gridline Debug."
            return
        }
        tapSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        if let tapSource { CFRunLoopAddSource(CFRunLoopGetMain(), tapSource, .commonModes) }
        CGEvent.tapEnable(tap: eventTap, enable: true)
        isInspecting = true
        inspectionStatus = "Pointer monitor is active. Hover or click a control in Gridline."
        refreshLogs()
    }

    func stopInspecting() {
        if let tapSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), tapSource, .commonModes) }
        if let eventTap { CFMachPortInvalidate(eventTap) }
        tapSource = nil
        eventTap = nil
        isInspecting = false
        hoverHighlight.hide()
        inspectionStatus = "Inspection is stopped."
    }

    func pinHovered() {
        pinned = hovered
        selectionIsClick = false
        copyStatus = ""
    }

    func select(_ event: InspectorEvent) {
        pinned = event.element
        selectionIsClick = event.kind == "left click" || event.kind == "right click"
        copyStatus = ""
    }

    func lastClick(for element: DebugElement) -> InspectorEvent? {
        clicks.last { $0.element == element && ($0.kind == "left click" || $0.kind == "right click") }
    }

    func copyElementContext() {
        guard let element = pinned ?? hovered else { return }
        refreshLogs()
        let click = lastClick(for: element)
        let text = GridlineCodeContext.makeCopyText(
            element: element,
            wasClicked: selectionIsClick,
            click: click,
            recentEvents: appEvents,
            projectRoot: Self.root.deletingLastPathComponent()
        )
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copyStatus = "Copied element, code path, and matching behavior events."
    }

    func refreshLogs() {
        let eventURL = debugDirectory.appendingPathComponent("events.jsonl")
        if let content = try? String(contentsOf: eventURL, encoding: .utf8) {
            appEvents = Array(content.split(separator: "\n").suffix(35).map(String.init))
        }
        let statusURL = debugDirectory.appendingPathComponent("build/latest-status.json")
        if let data = try? Data(contentsOf: statusURL),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
            buildStatus = "\(json["status"] ?? "unknown") · \(json["time"] ?? "") · \(json["target"] ?? "")"
        }
        let summaryURL = debugDirectory.appendingPathComponent("build/latest-errors.txt")
        buildErrors = (try? String(contentsOf: summaryURL, encoding: .utf8)) ?? ""
    }

    func saveReport() throws -> URL {
        guard let element = pinned ?? hovered else { throw ReportError.noElement }
        refreshLogs()
        let reports = debugDirectory.appendingPathComponent("reports", isDirectory: true)
        try FileManager.default.createDirectory(at: reports, withIntermediateDirectories: true)
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let url = reports.appendingPathComponent("issue-\(stamp).md")
        let selectedEvents = clicks.suffix(25)
        let clickLines = selectedEvents.map {
            "- \($0.time.formatted(date: .numeric, time: .standard)) · \($0.kind) · \($0.element.app) · \($0.element.role) · \($0.element.title) · \($0.detail)"
        }.joined(separator: "\n")
        let appLog = appEvents.suffix(25).joined(separator: "\n")
        let codePath = GridlineCodeContext.sourcePath(for: element)
        let expectedEvents = GridlineCodeContext.expectedEvents(for: element)
        let report = """
        # Gridline UI element context

        **Selection:** \(selectionIsClick ? "Clicked in Gridline" : "Hovered or manually pinned")

        ## Selected element

        - App: `\(element.app)` (`\(element.bundleID)`)
        - Role: `\(element.role)` / `\(element.subrole)`
        - Title: `\(element.title)`
        - Accessibility identifier: `\(element.identifier)`
        - Help: `\(element.help)`
        - Search hint for code: `\(element.searchHint)`
        - Hierarchy: `\(element.hierarchy.joined(separator: " → "))`
        - Process ID: `\(element.pid)`

        ## Likely code path

        \(codePath)

        ## Expected semantic events

        \(expectedEvents)

        ## Click and selection history

        \(clickLines.isEmpty ? "(no clicks captured yet)" : clickLines)

        ## App interaction log (`events.jsonl`)

        ```jsonl
        \(appLog.isEmpty ? "(no app events recorded yet)" : appLog)
        ```

        ## Latest build

        \(buildStatus)

        ```text
        \(buildErrors.isEmpty ? "No compiler errors in the latest build." : buildErrors)
        ```

        ## Files for the coding agent

        Start with `gridline_debug/INDEX.md`. Search the project for the accessibility identifier, visible title, or `Search hint for code` above. The Accessibility hierarchy identifies the runtime element; it does not claim a Swift source line.

        Structured companion: `\(url.deletingPathExtension().lastPathComponent).json`
        """
        try report.write(to: url, atomically: true, encoding: .utf8)
        let structured = StructuredIssue(
            createdAt: Date(),
            selectionIsClick: selectionIsClick,
            selectedElement: element,
            likelyCodePath: codePath,
            expectedEvents: expectedEvents,
            capturedEvents: Array(selectedEvents),
            gridlineEvents: Array(appEvents.suffix(35)),
            latestBuild: buildStatus,
            latestBuildErrors: buildErrors
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonURL = url.deletingPathExtension().appendingPathExtension("json")
        try encoder.encode(structured).write(to: jsonURL, options: .atomic)
        return url
    }

    private func receive(_ type: CGEventType) {
        guard isInspecting else { return }
        inspectionStatus = "Pointer events are arriving; move over or click a Gridline control."
        if type == .mouseMoved, Date().timeIntervalSince(lastHoverUpdate) < 0.12 { return }
        lastHoverUpdate = Date()
        hoverGeneration += 1
        let generation = hoverGeneration
        let point = DebugElement.currentAXPoint()
        Task { @MainActor [weak self] in
            let element = await Task.detached(priority: .userInitiated) { DebugElement.atPoint(point) }.value
            guard let self else { return }
            if generation == self.hoverGeneration || type == .leftMouseDown || type == .rightMouseDown {
                self.hoverHighlight.show(element)
                if element != nil, element?.highlightFrame == nil {
                    self.inspectionStatus = "Found the Gridline element, but macOS did not provide its screen bounds for the highlight."
                }
            }
            if let element, (type == .leftMouseDown || type == .rightMouseDown) {
                self.hovered = element
                self.pinned = element
                self.selectionIsClick = true
                self.copyStatus = ""
                self.addClick(element, kind: type == .leftMouseDown ? "left click" : "right click", detail: "Gridline control clicked")
            } else if element == nil, type == .leftMouseDown || type == .rightMouseDown {
                self.inspectionStatus = "Click received, but Gridline did not expose an Accessibility element at that point. Make sure the pointer is over the Gridline window."
            } else if generation == self.hoverGeneration {
                self.hovered = element
            }
        }
    }

    private func addClick(_ element: DebugElement, kind: String, detail: String) {
        clicks.append(InspectorEvent(kind: kind, element: element, detail: detail))
        if clicks.count > 250 { clicks.removeFirst(clicks.count - 250) }
        guard kind == "left click" || kind == "right click" || kind == "selected" else { return }
        watchApp(pid: pid_t(element.pid))
    }

    private func watchApp(pid: pid_t) {
        guard watchedPID != pid else { return }
        changeWatcher?.stop()
        watchedPID = pid
        changeWatcher = AXChangeWatcher(pid: pid) { [weak self] notification in
            guard let self, let element = self.pinned ?? self.hovered else { return }
            self.clicks.append(InspectorEvent(kind: "AX change", element: element, detail: notification))
            if self.clicks.count > 250 { self.clicks.removeFirst(self.clicks.count - 250) }
        }
    }
}

private struct StructuredIssue: Codable {
    let createdAt: Date
    let selectionIsClick: Bool
    let selectedElement: DebugElement
    let likelyCodePath: String
    let expectedEvents: String
    let capturedEvents: [InspectorEvent]
    let gridlineEvents: [String]
    let latestBuild: String
    let latestBuildErrors: String
}

enum ReportError: LocalizedError {
    case noElement
    var errorDescription: String? { "Hover over or pin an element before saving a report." }
}
