import Foundation
import SwiftUI

struct CodexUsageWindow: Codable, Sendable {
    let usedPercent: Int?
    let windowDurationMins: Int?
    let resetsAt: Double?
}

struct CodexBudgetSnapshot: Codable, Sendable {
    let plan: String?
    let primary: CodexUsageWindow?
    let secondary: CodexUsageWindow?
    let threadTokens: Int?
}

/// Reusable reader for the user's Codex allowance monitor. It retains only
/// aggregate counts and never reads or displays prompts or terminal output.
@MainActor
final class CodexUsageStatus: ObservableObject {
    private static let automaticRefreshKey = "gridline.usage.codex.automaticRefresh"
    private static let intervalKey = "gridline.usage.codex.intervalMilliseconds"
    private static let snapshotKey = "gridline.usage.codex.lastSnapshot"
    static let minimumIntervalMilliseconds = 1_000
    static let maximumIntervalMilliseconds = 3_600_000

    @Published private(set) var plan: String?
    @Published private(set) var primary: CodexUsageWindow?
    @Published private(set) var secondary: CodexUsageWindow?
    @Published private(set) var threadTokens: Int?
    @Published private(set) var hasChecked = false
    @Published private(set) var automaticRefreshEnabled: Bool
    @Published private(set) var refreshIntervalMilliseconds: Int
    private var monitorProcess: Process?
    private var monitorOutputPipe: Pipe?
    private var isRefreshingOnce = false

    init() {
        let defaults = UserDefaults.standard
        automaticRefreshEnabled = defaults.object(forKey: Self.automaticRefreshKey) as? Bool ?? true
        let savedInterval = defaults.integer(forKey: Self.intervalKey)
        refreshIntervalMilliseconds = savedInterval == 0
            ? 3_000
            : min(max(savedInterval, Self.minimumIntervalMilliseconds), Self.maximumIntervalMilliseconds)

        if let data = defaults.data(forKey: Self.snapshotKey),
           let snapshot = try? JSONDecoder().decode(CodexBudgetSnapshot.self, from: data) {
            apply(snapshot, persist: false)
        }

        if automaticRefreshEnabled { startMonitor() }
    }

    deinit { monitorProcess?.interrupt() }

    func setAutomaticRefreshEnabled(_ enabled: Bool) {
        guard automaticRefreshEnabled != enabled else { return }
        automaticRefreshEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.automaticRefreshKey)
        if enabled {
            startMonitor()
        } else {
            stopMonitor()
        }
    }

    func setRefreshIntervalMilliseconds(_ milliseconds: Int) {
        let value = min(max(milliseconds, Self.minimumIntervalMilliseconds), Self.maximumIntervalMilliseconds)
        guard refreshIntervalMilliseconds != value else { return }
        refreshIntervalMilliseconds = value
        UserDefaults.standard.set(value, forKey: Self.intervalKey)
        if automaticRefreshEnabled { startMonitor() }
    }

    func refreshOnce() {
        guard !isRefreshingOnce else { return }
        isRefreshingOnce = true
        DispatchQueue.global(qos: .utility).async {
            let snapshot = Self.readBudgetSnapshot()
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let snapshot { self.apply(snapshot) }
                self.hasChecked = true
                self.isRefreshingOnce = false
            }
        }
    }

    private func apply(_ snapshot: CodexBudgetSnapshot, persist: Bool = true) {
        plan = snapshot.plan
        primary = snapshot.primary
        secondary = snapshot.secondary
        threadTokens = snapshot.threadTokens
        hasChecked = true
        if persist, let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: Self.snapshotKey)
        }
    }

    private func startMonitor() {
        stopMonitor()
        guard automaticRefreshEnabled,
              let monitorURL = Bundle.main.resourceURL?.appendingPathComponent("usage/monitor.py"),
              FileManager.default.isReadableFile(atPath: monitorURL.path) else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        let seconds = Double(refreshIntervalMilliseconds) / 1_000
        process.arguments = ["python3", monitorURL.path, "--watch-json", "--interval", String(format: "%.3f", locale: Locale(identifier: "en_US_POSIX"), seconds)]
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        process.environment = environment
        let output = Pipe()
        process.standardOutput = output
        DebugEvents.configurePythonProcess(
            process,
            workflow: "codex_allowance",
            script: "monitor.py",
            swiftStage: "CodexUsageStatus.startMonitor"
        )
        process.terminationHandler = { finished in
            DebugEvents.recordPythonProcessFinished(
                workflow: "codex_allowance",
                script: "monitor.py",
                swiftStage: "CodexUsageStatus.startMonitor",
                exitCode: finished.terminationStatus
            )
        }

        do {
            try process.run()
            monitorProcess = process
            monitorOutputPipe = output
        } catch {
            DebugEvents.recordPythonProcessFinished(
                workflow: "codex_allowance",
                script: "monitor.py",
                swiftStage: "CodexUsageStatus.startMonitor",
                exitCode: -1
            )
            hasChecked = true
            scheduleMonitorRestart()
            return
        }

        let handle = output.fileHandleForReading
        DispatchQueue.global(qos: .utility).async { [weak self, weak process] in
            var pending = Data()
            let newline = Data([0x0A])
            while true {
                let chunk = handle.readData(ofLength: 4_096)
                guard !chunk.isEmpty else { break }
                pending.append(chunk)
                while let range = pending.range(of: newline) {
                    let line = Data(pending[..<range.lowerBound])
                    pending.removeSubrange(..<range.upperBound)
                    guard let snapshot = try? JSONDecoder().decode(CodexBudgetSnapshot.self, from: line) else { continue }
                    Task { @MainActor [weak self, weak process] in
                        guard let self, let process, self.monitorProcess === process else { return }
                        self.apply(snapshot)
                    }
                }
            }
            Task { @MainActor [weak self, weak process] in
                guard let self, let process, self.monitorProcess === process else { return }
                self.monitorProcess = nil
                self.monitorOutputPipe = nil
                self.scheduleMonitorRestart()
            }
        }
    }

    private func scheduleMonitorRestart() {
        guard automaticRefreshEnabled else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            guard let self, self.automaticRefreshEnabled, self.monitorProcess == nil else { return }
            self.startMonitor()
        }
    }

    private func stopMonitor() {
        let process = monitorProcess
        monitorProcess = nil
        monitorOutputPipe = nil
        if process?.isRunning == true { process?.interrupt() }
    }

    nonisolated private static func readBudgetSnapshot() -> CodexBudgetSnapshot? {
        guard let monitorURL = Bundle.main.resourceURL?.appendingPathComponent("usage/monitor.py") else { return nil }
        guard FileManager.default.isReadableFile(atPath: monitorURL.path) else { return nil }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["python3", monitorURL.path, "--once", "--json"]
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        process.environment = environment
        let output = Pipe()
        process.standardOutput = output
        DebugEvents.configurePythonProcess(
            process,
            workflow: "codex_allowance",
            script: "monitor.py",
            swiftStage: "CodexUsageStatus.readBudgetSnapshot"
        )

        do {
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            DebugEvents.recordPythonProcessFinished(
                workflow: "codex_allowance",
                script: "monitor.py",
                swiftStage: "CodexUsageStatus.readBudgetSnapshot",
                exitCode: process.terminationStatus
            )
            guard process.terminationStatus == 0 else { return nil }
            return try JSONDecoder().decode(CodexBudgetSnapshot.self, from: data)
        } catch {
            return nil
        }
    }
}

struct ProviderUsageSnapshot: Sendable {
    let codexActiveTerminals: Int
    let claudeActiveTerminals: Int
    let otherActiveTerminals: Int
    let claudeAPIEquivalentUSD: Double?
    let claudeUnpricedModels: [String]

    static let checking = ProviderUsageSnapshot(
        codexActiveTerminals: 0,
        claudeActiveTerminals: 0,
        otherActiveTerminals: 0,
        claudeAPIEquivalentUSD: nil,
        claudeUnpricedModels: []
    )
}

struct TerminalProcessReference: Sendable {
    let id: UUID
    let shellPID: Int32
}

private struct ClaudeCostEstimate: Decodable {
    let amountUSD: Double?
    let available: Bool
    let unpricedModels: [String: Int]?
}

/// Collects provider cost estimates and running CLI names independently from
/// the template UI. Python scripts provide reusable local usage snapshots.
@MainActor
final class ProviderUsageStatus: ObservableObject {
    @Published private(set) var snapshot = ProviderUsageSnapshot.checking
    private var terminals: [TerminalProcessReference] = []
    private var processTimer: Timer?
    private var costTimer: Timer?
    private var isReadingCosts = false

    init() {
        refreshProcessStatus()
        refreshCostEstimates()
        processTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refreshProcessStatus() }
        }
        costTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refreshCostEstimates() }
        }
    }

    deinit {
        processTimer?.invalidate()
        costTimer?.invalidate()
    }

    func updateTerminals(_ sessions: [TerminalSession]) {
        terminals = sessions.map { TerminalProcessReference(id: $0.id, shellPID: $0.terminal.process.shellPid) }
        refreshProcessStatus()
    }

    private func refreshProcessStatus() {
        let references = terminals
        DispatchQueue.global(qos: .utility).async {
            let counts = Self.detectProviders(for: references)
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.snapshot = ProviderUsageSnapshot(
                    codexActiveTerminals: counts["codex", default: 0],
                    claudeActiveTerminals: counts["claude", default: 0],
                    otherActiveTerminals: counts.filter { !["codex", "claude"].contains($0.key) }.values.reduce(0, +),
                    claudeAPIEquivalentUSD: self.snapshot.claudeAPIEquivalentUSD,
                    claudeUnpricedModels: self.snapshot.claudeUnpricedModels
                )
            }
        }
    }

    private func refreshCostEstimates() {
        guard !isReadingCosts else { return }
        isReadingCosts = true
        DispatchQueue.global(qos: .utility).async {
            let claude = Self.readJSON(ClaudeCostEstimate.self, scriptName: "claude_usage.py")
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.snapshot = ProviderUsageSnapshot(
                    codexActiveTerminals: self.snapshot.codexActiveTerminals,
                    claudeActiveTerminals: self.snapshot.claudeActiveTerminals,
                    otherActiveTerminals: self.snapshot.otherActiveTerminals,
                    claudeAPIEquivalentUSD: claude?.available == true ? claude?.amountUSD : nil,
                    claudeUnpricedModels: claude?.unpricedModels.map { Array($0.keys).sorted() } ?? []
                )
                self.isReadingCosts = false
            }
        }
    }

    nonisolated private static func readJSON<T: Decodable>(_ type: T.Type, scriptName: String) -> T? {
        guard let scriptURL = Bundle.main.resourceURL?.appendingPathComponent("usage/\(scriptName)") else { return nil }
        guard FileManager.default.isReadableFile(atPath: scriptURL.path) else { return nil }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["python3", scriptURL.path]
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        process.environment = environment
        let output = Pipe()
        process.standardOutput = output
        DebugEvents.configurePythonProcess(
            process,
            workflow: scriptName.replacingOccurrences(of: ".py", with: ""),
            script: scriptName,
            swiftStage: "ProviderUsageService.readJSON"
        )
        do {
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            DebugEvents.recordPythonProcessFinished(
                workflow: scriptName.replacingOccurrences(of: ".py", with: ""),
                script: scriptName,
                swiftStage: "ProviderUsageService.readJSON",
                exitCode: process.terminationStatus
            )
            guard process.terminationStatus == 0 else { return nil }
            return try JSONDecoder().decode(type, from: data)
        } catch {
            return nil
        }
    }

    nonisolated private static func detectProviders(for references: [TerminalProcessReference]) -> [String: Int] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-Ao", "pid=", "-o", "ppid=", "-o", "comm="]
        let output = Pipe()
        process.standardOutput = output
        DebugEvents.recordExternalProcess(
            workflow: "terminal_provider_detection",
            executable: "ps",
            stage: "TerminalUsageStatus.detectProviders",
            status: "started"
        )
        do {
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            DebugEvents.recordExternalProcess(
                workflow: "terminal_provider_detection",
                executable: "ps",
                stage: "TerminalUsageStatus.detectProviders",
                status: process.terminationStatus == 0 ? "completed" : "failed",
                exitCode: process.terminationStatus
            )
            guard process.terminationStatus == 0,
                  let listing = String(data: data, encoding: .utf8) else { return [:] }

            var parentByPID: [Int32: Int32] = [:]
            var nameByPID: [Int32: String] = [:]
            for line in listing.split(separator: "\n") {
                let fields = line.split(maxSplits: 2, whereSeparator: { $0.isWhitespace })
                guard fields.count == 3, let pid = Int32(fields[0]), let parent = Int32(fields[1]) else { continue }
                parentByPID[pid] = parent
                nameByPID[pid] = URL(fileURLWithPath: String(fields[2])).lastPathComponent.lowercased()
            }

            let providerNames: [String: Set<String>] = [
                "codex": ["codex"],
                "claude": ["claude"],
                "gemini": ["gemini", "gemini-cli"],
                "opencode": ["opencode"],
                "aider": ["aider"],
                "cursor": ["cursor-agent"],
                "copilot": ["copilot", "gh-copilot"],
                "ollama": ["ollama"]
            ]
            var counts: [String: Int] = [:]
            for reference in references where reference.shellPID > 0 {
                let descendants = Set(parentByPID.compactMap { pid, parent in
                    var ancestor = parent
                    var visited: Set<Int32> = []
                    while ancestor != 0, visited.insert(ancestor).inserted {
                        if ancestor == reference.shellPID { return pid }
                        ancestor = parentByPID[ancestor] ?? 0
                    }
                    return nil
                })
                let names = descendants.compactMap { nameByPID[$0] }
                if let provider = providerNames.first(where: { _, namesForProvider in names.contains(where: namesForProvider.contains) })?.key {
                    counts[provider, default: 0] += 1
                }
            }
            return counts
        } catch {
            return [:]
        }
    }
}

struct TerminalUsageSnapshot: Decodable, Sendable, Identifiable {
    let terminalID: UUID
    let status: String
    let provider: String?
    let sessionID: String?
    let model: String?
    let models: [String]?
    let inputTokens: Int?
    let outputTokens: Int?
    let totalTokens: Int?
    let latestTurnInputTokens: Int?
    let latestTurnOutputTokens: Int?
    let latestTurnTotalTokens: Int?
    let cachedInputTokens: Int?
    let cacheWriteInputTokens: Int?
    let cacheReadInputTokens: Int?
    let reasoningOutputTokens: Int?
    let amountUSD: Double?
    let unpricedModels: [String]?
    let updatedAt: String?
    let diagnostic: String?
    let candidateCount: Int?
    let errorType: String?
    let rowsRead: Int?
    let usageRowsParsed: Int?
    let readerTrace: [String]?
    let providerProcessStartedAt: String?
    let submissionAt: Double?
    let submissionResolution: String?

    var id: UUID { terminalID }
    var hasPartialEstimate: Bool { !(unpricedModels ?? []).isEmpty }
}

private struct TerminalUsagePayload: Decodable {
    let terminals: [TerminalUsageSnapshot]
}

private struct TerminalUsageReference: Encodable, Equatable {
    let id: String
    let groupID: String
    let groupName: String
    let shellPID: Int32
    let directory: String
}

/// Reads usage metadata for Gridline PTYs and normalizes Python JSON into snapshots.
/// Flow: WorkspaceView.updateTerminals -> startMonitor -> terminal_usage.py -> apply -> template.
/// Diagnostic token totals and parser stages are logged only while Gridline Debug is open.
@MainActor
final class TerminalUsageStatus: ObservableObject {
    private static let enabledKey = "gridline.usage.terminals.enabled"

    @Published private(set) var snapshots: [UUID: TerminalUsageSnapshot] = [:]
    @Published private(set) var updatesEnabled: Bool
    private var references: [TerminalUsageReference] = []
    private var monitorProcess: Process?
    private var monitorInputPipe: Pipe?
    private var monitorOutputPipe: Pipe?
    private var lastDiagnosticByTerminal: [UUID: String] = [:]
    private var reportedPayloadDecodeFailure = false
    private var groupNames: [String: String] = [:]

    init() {
        updatesEnabled = UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true
    }

    deinit { monitorProcess?.interrupt() }

    func updateGroupNames(_ groups: [SavedGroup]) {
        groupNames = Dictionary(uniqueKeysWithValues: groups.map { ($0.id.uuidString, $0.name) })
    }

    func updateTerminals(_ sessions: [TerminalSession]) {
        for session in sessions {
            let terminalID = session.id
            session.terminal.onSubmission = { [weak self] in
                self?.noteTerminalSubmission(terminalID)
            }
        }
        let next = sessions.map {
            TerminalUsageReference(
                id: $0.id.uuidString,
                groupID: $0.groupID.uuidString,
                groupName: groupNames[$0.groupID.uuidString] ?? "Unknown workgroup",
                shellPID: $0.terminal.process.shellPid,
                directory: $0.launchDirectory
            )
        }
        let nextByID = Dictionary(uniqueKeysWithValues: next.map { ($0.id, $0) })
        let previousByID = Dictionary(uniqueKeysWithValues: references.map { ($0.id, $0) })
        for (id, previous) in previousByID {
            guard let current = nextByID[id], current.shellPID != previous.shellPID,
                  let terminalID = UUID(uuidString: id) else { continue }
            snapshots[terminalID] = nil
            lastDiagnosticByTerminal[terminalID] = nil
            DebugEvents.recordDiagnostic(
                "workspace.terminalUsageReset",
                element: "gridline.session.usage.\(id)",
                details: [
                    "reason": "terminal_process_changed",
                    "pipeline": "WorkspaceView.updateTerminals > TerminalUsageStatus.resetSnapshot"
                ]
            )
        }
        let nextIDs = Set(next.map(\.id))
        for removed in references where !nextIDs.contains(removed.id) {
            if let terminalID = UUID(uuidString: removed.id) {
                snapshots[terminalID] = nil
                lastDiagnosticByTerminal[terminalID] = nil
            }
        }
        guard next != references else { return }
        references = next
        if updatesEnabled { startMonitor() }
    }

    private func noteTerminalSubmission(_ terminalID: UUID) {
        let submittedAt = Date().timeIntervalSince1970
        let reference = references.first { $0.id == terminalID.uuidString }
        let element = "gridline.session.usage.\(terminalID.uuidString)"
        let baseDetails = [
            "session": terminalID.uuidString,
            "groupID": reference?.groupID ?? "unknown",
            "groupName": reference?.groupName ?? "Unknown Workgroup",
            "submittedAt": String(format: "%.3f", submittedAt),
            "pipeline": "Workspace.swift:GridlineTerminalView.send(Enter) > ProviderUsageService.swift:TerminalUsageStatus.noteTerminalSubmission > terminal_usage.py:read_submission_updates"
        ]
        guard updatesEnabled else {
            DebugEvents.recordDiagnostic(
                "workspace.terminalUsageSubmissionNotForwarded",
                element: element,
                details: baseDetails.merging(["reason": "monitor_paused"]) { _, value in value }
            )
            return
        }
        guard monitorProcess?.isRunning == true,
              let input = monitorInputPipe?.fileHandleForWriting,
              let data = try? JSONEncoder().encode(TerminalUsageSubmission(
                terminalID: terminalID.uuidString,
                submittedAt: submittedAt
              )) else {
            DebugEvents.recordDiagnostic(
                "workspace.terminalUsageSubmissionNotForwarded",
                element: element,
                details: baseDetails.merging(["reason": "reader_not_running"]) { _, value in value }
            )
            return
        }
        do {
            try input.write(contentsOf: data + Data([0x0A]))
            DebugEvents.recordDiagnostic(
                "workspace.terminalUsageSubmissionForwarded",
                element: element,
                details: baseDetails.merging(["status": "forwarded"]) { _, value in value }
            )
        } catch {
            DebugEvents.recordDiagnostic(
                "workspace.terminalUsageSubmissionNotForwarded",
                element: element,
                details: baseDetails.merging([
                    "reason": "pipe_write_failed",
                    "errorType": String(describing: type(of: error))
                ]) { _, value in value }
            )
        }
    }

    func setUpdatesEnabled(_ enabled: Bool) {
        guard updatesEnabled != enabled else { return }
        updatesEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.enabledKey)
        DebugEvents.record(
            "workspace.terminalUsageUpdatesChanged",
            element: "gridline.workspace.terminalUsage.disable",
            details: ["enabled": String(enabled)]
        )
        if enabled {
            startMonitor()
        } else {
            stopMonitor()
        }
    }

    private func startMonitor() {
        stopMonitor()
        guard updatesEnabled, !references.isEmpty else { return }
        guard let scriptURL = Bundle.main.resourceURL?.appendingPathComponent("usage/terminal_usage.py"),
              FileManager.default.isReadableFile(atPath: scriptURL.path) else {
            recordMonitorFailure(reason: "reader_script_missing")
            return
        }
        guard let inputData = try? JSONEncoder().encode(TerminalUsageRequest(
            terminals: references
        )) else {
            recordMonitorFailure(reason: "terminal_request_encoding_failed")
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["python3", scriptURL.path]
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        process.environment = environment

        let input = Pipe()
        let output = Pipe()
        process.standardInput = input
        process.standardOutput = output
        DebugEvents.configurePythonProcess(
            process,
            workflow: "terminal_usage",
            script: "terminal_usage.py",
            swiftStage: "TerminalUsageStatus.startMonitor"
        )
        do {
            try process.run()
            monitorProcess = process
            monitorInputPipe = input
            monitorOutputPipe = output
            process.terminationHandler = { [weak self, weak process] _ in
                Task { @MainActor [weak self, weak process] in
                    guard let self, let process, self.monitorProcess === process else { return }
                    DebugEvents.recordPythonProcessFinished(
                        workflow: "terminal_usage",
                        script: "terminal_usage.py",
                        swiftStage: "TerminalUsageStatus.startMonitor",
                        exitCode: process.terminationStatus
                    )
                    self.monitorProcess = nil
                    self.monitorOutputPipe = nil
                    if process.terminationStatus != 0 {
                        self.recordMonitorFailure(reason: "reader_process_exited", errorType: "exit_\(process.terminationStatus)")
                    }
                    self.scheduleMonitorRestart()
                }
            }
            let decoder = TerminalUsageLineDecoder()
            output.fileHandleForReading.readabilityHandler = { [weak self, decoder] handle in
                let data = handle.availableData
                guard !data.isEmpty else {
                    handle.readabilityHandler = nil
                    return
                }
                for line in decoder.append(data) {
                    guard let payload = try? JSONDecoder().decode(TerminalUsagePayload.self, from: line) else {
                        Task { @MainActor [weak self] in
                            guard let self, !self.reportedPayloadDecodeFailure else { return }
                            self.reportedPayloadDecodeFailure = true
                            self.recordMonitorFailure(reason: "reader_payload_decode_failed")
                        }
                        continue
                    }
                    Task { @MainActor [weak self] in self?.apply(payload) }
                }
            }
            try input.fileHandleForWriting.write(contentsOf: inputData + Data([0x0A]))
        } catch {
            monitorProcess = nil
            try? input.fileHandleForWriting.close()
            monitorInputPipe = nil
            monitorOutputPipe?.fileHandleForReading.readabilityHandler = nil
            monitorOutputPipe = nil
            if process.isRunning { process.terminate() }
            recordMonitorFailure(reason: "reader_process_launch_failed", errorType: String(describing: type(of: error)))
        }
    }

    private func stopMonitor() {
        let process = monitorProcess
        monitorProcess = nil
        try? monitorInputPipe?.fileHandleForWriting.close()
        monitorInputPipe = nil
        monitorOutputPipe?.fileHandleForReading.readabilityHandler = nil
        monitorOutputPipe = nil
        if process?.isRunning == true { process?.interrupt() }
    }

    private func scheduleMonitorRestart() {
        guard updatesEnabled, !references.isEmpty else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            guard let self, self.updatesEnabled, self.monitorProcess == nil else { return }
            self.startMonitor()
        }
    }

    private func apply(_ payload: TerminalUsagePayload) {
        guard updatesEnabled else { return }
        for snapshot in payload.terminals {
            let retainsConfirmedSnapshot = snapshot.status != "available"
                && snapshots[snapshot.terminalID]?.status == "available"
            recordDiagnosticIfChanged(for: snapshot, retainingPrevious: retainsConfirmedSnapshot)
            if retainsConfirmedSnapshot {
                continue
            }
            snapshots[snapshot.terminalID] = snapshot
        }
    }

    private func recordDiagnosticIfChanged(for snapshot: TerminalUsageSnapshot, retainingPrevious: Bool) {
        guard DebugEvents.isInspectorOpen else { return }
        let count = snapshot.candidateCount.map { String($0) } ?? "unknown"
        let reason = snapshot.diagnostic ?? "unspecified"
        let provider = snapshot.provider ?? "unknown"
        let errorType = snapshot.errorType ?? "none"
        let inputReported = snapshot.inputTokens != nil
        let outputReported = snapshot.outputTokens != nil
        let totalReported = snapshot.totalTokens != nil
        let usageDataPresent = snapshot.updatedAt != nil
        let inputTokens = snapshot.inputTokens.map(String.init) ?? "missing"
        let outputTokens = snapshot.outputTokens.map(String.init) ?? "missing"
        let totalTokens = snapshot.totalTokens.map(String.init) ?? "missing"
        let latestTurnInputTokens = snapshot.latestTurnInputTokens.map(String.init) ?? "missing"
        let latestTurnOutputTokens = snapshot.latestTurnOutputTokens.map(String.init) ?? "missing"
        let latestTurnTotalTokens = snapshot.latestTurnTotalTokens.map(String.init) ?? "missing"
        let model = snapshot.model ?? "unknown"
        let rowsRead = snapshot.rowsRead.map(String.init) ?? "unknown"
        let usageRowsParsed = snapshot.usageRowsParsed.map(String.init) ?? "unknown"
        let readerTrace = snapshot.readerTrace?.joined(separator: " > ") ?? "terminal_usage.py:\(reason)"
        let providerSession = snapshot.sessionID ?? "unknown"
        let amountUSD = snapshot.amountUSD.map { String(format: "%.6f", $0) } ?? "unknown"
        let providerProcessStartedAt = snapshot.providerProcessStartedAt ?? "unknown"
        let submissionAt = snapshot.submissionAt.map { String(format: "%.3f", $0) } ?? "none"
        let submissionResolution = snapshot.submissionResolution ?? "none"
        let groupID = references.first(where: { $0.id == snapshot.terminalID.uuidString })?.groupID ?? "unknown"
        let groupName = groupNames[groupID] ?? "Unknown Workgroup"
        let signature = [
            snapshot.status,
            provider,
            count,
            reason,
            errorType,
            String(inputReported),
            String(outputReported),
            String(totalReported),
            String(usageDataPresent),
            inputTokens,
            outputTokens,
            totalTokens,
            latestTurnInputTokens,
            latestTurnOutputTokens,
            latestTurnTotalTokens,
            model,
            providerSession,
            amountUSD,
            providerProcessStartedAt,
            submissionAt,
            submissionResolution,
            String(retainingPrevious),
            rowsRead,
            usageRowsParsed,
            readerTrace,
            groupName
        ].joined(separator: "|")
        guard lastDiagnosticByTerminal[snapshot.terminalID] != signature else { return }
        lastDiagnosticByTerminal[snapshot.terminalID] = signature
        var details = [
            "session": snapshot.terminalID.uuidString,
            "status": snapshot.status,
            "provider": provider,
            "candidateCount": count,
            "reason": reason,
            "inputReported": String(inputReported),
            "outputReported": String(outputReported),
            "totalReported": String(totalReported),
            "usageDataPresent": String(usageDataPresent),
            "inputTokens": inputTokens,
            "outputTokens": outputTokens,
            "totalTokens": totalTokens,
            "latestTurnInputTokens": latestTurnInputTokens,
            "latestTurnOutputTokens": latestTurnOutputTokens,
            "latestTurnTotalTokens": latestTurnTotalTokens,
            "model": model,
            "providerSession": providerSession,
            "amountUSD": amountUSD,
            "providerProcessStartedAt": providerProcessStartedAt,
            "submissionAt": submissionAt,
            "submissionResolution": submissionResolution,
            "feature": "TERMINAL_HEADER",
            "featurePrefix": "TERMINAL_HEADER - usage status changed",
            "displayPolicy": retainingPrevious ? "kept_last_confirmed" : "updated_from_reader",
            "rowsRead": rowsRead,
            "usageRowsParsed": usageRowsParsed,
            "pipeline": "Workspace.swift:WorkspaceView > ProviderUsageService.swift:TerminalUsageStatus.apply > \(readerTrace) > MainTemplateWorkGroupCard.swift:terminalUsageButton"
        ]
        details["groupID"] = groupID
        details["groupName"] = groupName
        if errorType != "none" { details["errorType"] = errorType }
        if snapshot.status == "available",
           let submission = DebugEvents.consumePendingSubmission(
               sessionID: snapshot.terminalID.uuidString,
               usageUpdatedAt: snapshot.updatedAt
           ) {
            details.merge(submission) { _, submittedValue in submittedValue }
            details["pipeline"] = "\(submission["submissionPipeline"] ?? "") > \(readerTrace) > MainTemplateWorkGroupCard.swift:terminalUsageButton"
        }
        DebugEvents.recordDiagnostic(
            "workspace.terminalUsageStatusChanged",
            element: "gridline.session.usage.\(snapshot.terminalID.uuidString)",
            details: details
        )
    }

    private func recordMonitorFailure(reason: String, errorType: String? = nil) {
        guard DebugEvents.isInspectorOpen else { return }
        var details = [
            "reason": reason,
            "pipeline": "Workspace.swift:WorkspaceView > ProviderUsageService.swift:TerminalUsageStatus.startMonitor > gridline/usage/terminal_usage.py"
        ]
        if let errorType { details["errorType"] = errorType }
        DebugEvents.recordDiagnostic(
            "workspace.terminalUsageMonitorFailed",
            element: "gridline.workspace.terminalUsage",
            details: details
        )
    }
}

private struct TerminalUsageRequest: Encodable {
    let terminals: [TerminalUsageReference]
}

private struct TerminalUsageSubmission: Encodable {
    let terminalID: String
    let submittedAt: Double
}

private final class TerminalUsageLineDecoder {
    private var buffer = Data()

    func append(_ data: Data) -> [Data] {
        buffer.append(data)
        var lines: [Data] = []
        while let newline = buffer.firstRange(of: Data([0x0A])) {
            lines.append(buffer[..<newline.lowerBound])
            buffer.removeSubrange(..<newline.upperBound)
        }
        return lines
    }
}
