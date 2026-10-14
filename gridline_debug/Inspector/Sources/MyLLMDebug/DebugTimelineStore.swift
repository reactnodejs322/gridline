import AppKit
import Combine
import Foundation

struct DebugTimelineEntry: Identifiable {
    let id: String
    let time: String
    let event: String
    let element: String
    let details: [String: String]

    init?(line: String, index: Int) {
        guard let data = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let event = object["event"] as? String else { return nil }
        self.id = "\(index)-\(event)"
        self.time = object["time"] as? String ?? ""
        self.event = event
        self.element = object["element"] as? String ?? ""
        self.details = object["details"] as? [String: String] ?? [:]
    }

    var groupName: String { details["groupName"] ?? "" }
    var submissionID: String { details["submissionID"] ?? "" }
    var isFailure: Bool {
        event.localizedCaseInsensitiveContains("failed")
            || details["status"] == "failed"
            || details["status"] == "reader_error"
            || event == "workspace.terminalUsageMonitorFailed"
    }
    var source: String {
        if event == "hot-reload.build" { return "Build" }
        if details["language"] == "Codex" { return "Codex" }
        if details["language"] == "Python" { return "Python" }
        if details["language"] == "Swift" { return "Swift" }
        if event.hasPrefix("runtime.") || event.hasPrefix("workspace.terminalUsage") { return "Swift" }
        return "UI"
    }
    var summary: String {
        let group = groupName.isEmpty ? "" : "\(groupName) · "
        switch event {
        case "prompt.submitted":
            return "\(group)Prompt: \(details["prompt"] ?? "")"
        case "terminal.inputSubmitted":
            return "\(group)Submitted #\(String(submissionID.prefix(8))) · \(details["characterCount"] ?? "?") characters"
        case "workspace.terminalUsageStatusChanged":
            let status = details["status"] ?? "unknown"
            let session = "SESSION IN \(details["inputTokens"] ?? "—")  OUT \(details["outputTokens"] ?? "—")  TOTAL \(details["totalTokens"] ?? "—")"
            let turn = "TURN IN \(details["latestTurnInputTokens"] ?? "—")  OUT \(details["latestTurnOutputTokens"] ?? "—")"
            return "\(group)\(session) · \(turn) · \(status)"
        case "runtime.pythonDebug":
            return "\(group)\(details["featurePrefix"] ?? "Python DEBUG") · \(details["counts"] ?? "")"
        case "hot-reload.build":
            return "Build \(details["status"] ?? "unknown") · \(details["target"] ?? "Gridline")"
        case "provider.compactionStarted":
            return "\(group)Compaction starting · \(details["trigger"] ?? "unknown") · terminal \(details["terminalSession"] ?? "unknown")"
        case "provider.compactionCompleted":
            return "\(group)Compaction completed · \(details["trigger"] ?? "unknown") · terminal \(details["terminalSession"] ?? "unknown")"
        case "provider.hooksConfigured":
            return "\(group)Codex hooks \(details["action"] ?? "updated") · \(details["status"] ?? "unknown")"
        case "provider.hooksPanelOpened":
            return "\(group)Project hooks opened"
        case "provider.ponytailVendorUpdated":
            return "Ponytail source updated · v\(details["version"] ?? "unknown") · \(details["commit"] ?? "unknown")"
        case "workgroup.actionsMenuToggled":
            return "\(group)Work-group actions \(details["expanded"] == "true" ? "opened" : "closed")"
        case "workspace.utilityMenuToggled":
            return "Workspace controls \(details["expanded"] == "true" ? "opened" : "closed")"
        default:
            let status = details["status"] ?? details["reason"] ?? ""
            return "\(group)\(event)\(status.isEmpty ? "" : " · \(status)")"
        }
    }
    var exportText: String {
        let fields = details.sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }.joined(separator: " · ")
        return "\(time) [\(source)] \(event) — \(fields)"
    }
}

@MainActor
final class DebugTimelineStore: ObservableObject {
    @Published private(set) var entries: [DebugTimelineEntry] = [] { didSet { writeUserViewState() } }
    @Published var category = "all" { didSet { writeUserViewState() } }
    @Published var workgroup = "All workgroups" { didSet { writeUserViewState() } }
    @Published var search = "" { didSet { writeUserViewState() } }
    @Published var isFollowing = true { didSet { writeUserViewState() } }
    @Published var copyStatus = ""

    private var directory: URL?
    private var timer: Timer?
    private var lastSignature = ""
    private var isActive = false

    func start(directory: URL) {
        self.directory = directory
        isActive = true
        refresh()
        writeUserViewState()
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isActive = false
        writeUserViewState()
    }

    func refresh() {
        guard let directory else { return }
        if FileManager.default.fileExists(atPath: directory.appendingPathComponent("build/clear-logs.request").path) {
            entries = []
            return
        }
        if copyStatus == "Clearing local logs…" { copyStatus = "Logs cleared." }
        let url = directory.appendingPathComponent("timeline.jsonl")
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else {
            entries = []
            lastSignature = ""
            return
        }
        let size = (attributes[.size] as? NSNumber)?.uint64Value ?? 0
        let modified = (attributes[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        let signature = "\(size):\(modified)"
        guard signature != lastSignature else { return }
        lastSignature = signature
        guard let handle = try? FileHandle(forReadingFrom: url) else { return }
        defer { try? handle.close() }
        let start = size > 4_000_000 ? size - 4_000_000 : 0
        try? handle.seek(toOffset: start)
        guard let data = try? handle.readToEnd() else { return }
        let content = String(decoding: data, as: UTF8.self)
        var lines = content.components(separatedBy: "\n")
        if !lines.isEmpty { lines.removeLast() } // Ignore an unfinished write.
        if start > 0 && !lines.isEmpty { lines.removeFirst() } // Ignore a partial first line.
        entries = lines.enumerated().compactMap { DebugTimelineEntry(line: $0.element, index: $0.offset) }
            .sorted { $0.time == $1.time ? $0.id < $1.id : $0.time < $1.time }
    }

    var workgroups: [String] {
        ["All workgroups"] + Set(entries.map(\.groupName).filter { !$0.isEmpty }).sorted()
    }

    var filteredEntries: [DebugTimelineEntry] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return entries.filter { entry in
            let categoryMatches: Bool
            switch category {
            case "terminal":
                categoryMatches = entry.event == "prompt.submitted"
                    || entry.event == "terminal.inputSubmitted"
                    || entry.event.hasPrefix("workspace.terminalUsage")
                    || entry.event == "runtime.pythonDebug"
            case "prompts": categoryMatches = entry.event == "prompt.submitted" || entry.event == "terminal.inputSubmitted"
            case "hooks": categoryMatches = entry.event.hasPrefix("provider.")
            case "usage": categoryMatches = entry.event.hasPrefix("workspace.terminalUsage")
            case "python": categoryMatches = entry.source == "Python"
            case "swift": categoryMatches = entry.source == "Swift"
            case "ui": categoryMatches = entry.source == "UI"
            case "build": categoryMatches = entry.source == "Build"
            case "failures": categoryMatches = entry.isFailure
            default: categoryMatches = true
            }
            guard categoryMatches else { return false }
            if workgroup != "All workgroups" && entry.groupName != workgroup { return false }
            if query.isEmpty { return true }
            return entry.exportText.localizedCaseInsensitiveContains(query)
        }
    }

    private func writeUserViewState() {
        guard let directory else { return }
        let categoryLabels = [
            "terminal": "Prompts + IN/OUT",
            "prompts": "Prompts",
            "hooks": "Codex hooks",
            "usage": "Usage updates",
            "python": "Python",
            "swift": "Swift",
            "ui": "UI",
            "build": "Builds",
            "failures": "Failures",
            "all": "Everything"
        ]
        let state: [String: Any] = [
            "updatedAt": ISO8601DateFormatter().string(from: Date()),
            "active": isActive,
            "show": categoryLabels[category] ?? category,
            "category": category,
            "workgroup": workgroup,
            "search": search,
            "following": isFollowing,
            "loadedCount": entries.count,
            "matchingCount": filteredEntries.count
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: state, options: [.sortedKeys]) else { return }
        try? data.write(to: directory.appendingPathComponent("user-log-view.json"), options: .atomic)
    }

    func copyFiltered() {
        let output = filteredEntries.map(\.exportText).joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(output, forType: .string)
        copyStatus = "Copied \(filteredEntries.count) filtered log entries."
    }

    func resetLogs() {
        guard let directory else { return }
        let request = directory.appendingPathComponent("build/clear-logs.request")
        do {
            try FileManager.default.createDirectory(at: request.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data("clear\n".utf8).write(to: request, options: .atomic)
            entries = []
            lastSignature = ""
            copyStatus = "Clearing local logs…"
        } catch {
            copyStatus = "Could not request log reset."
        }
    }
}
