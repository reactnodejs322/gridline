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
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            monitorProcess = process
            monitorOutputPipe = output
        } catch {
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
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
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
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
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
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
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
