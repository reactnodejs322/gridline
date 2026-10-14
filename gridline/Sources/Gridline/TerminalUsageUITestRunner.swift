import Foundation

/// Test-only entry point used by tests/gridline_terminal_usage_test/run.sh.
/// It submits fixed prompts through the same PTY and usage-submission path as a terminal.
@MainActor
final class TerminalUsageUITestRunner {
    private struct Target {
        let group: SavedGroup
        let session: TerminalSession
    }

    private let workspace: WorkspaceStore
    private let usage: TerminalUsageStatus
    private let responseCheckWindow: TimeInterval = 15
    private var reportURL: URL?

    static var reportURLFromArguments: URL? {
        guard let index = ProcessInfo.processInfo.arguments.firstIndex(of: "--terminal-usage-test"),
              ProcessInfo.processInfo.arguments.indices.contains(index + 1) else { return nil }
        return URL(fileURLWithPath: ProcessInfo.processInfo.arguments[index + 1])
    }

    init(workspace: WorkspaceStore, usage: TerminalUsageStatus) {
        self.workspace = workspace
        self.usage = usage
    }

    func run(reportURL: URL) async {
        self.reportURL = reportURL
        _ = FileManager.default.createFile(atPath: reportURL.path, contents: Data())
        emit("Starting Test 1 only: terminal 1ABC.")
        emit("Gridline and Gridline Debug were freshly launched; completed test prompts are stored in the local Debug timeline, while responses are not recorded.")

        let passed = await check(groupContaining: "1ABC", number: 1)
        emit("RESULT \(passed ? "PASS" : "FAIL")")
    }

    private func check(groupContaining marker: String, number: Int) async -> Bool {
        guard let target = target(containing: marker) else {
            emit("Test \(number) FAIL — no active saved terminal in workgroup matching \(marker).")
            return false
        }
        emit("\nTest \(number): \(target.group.name) · session \(target.session.id.uuidString)")
        let readinessDeadline = Date().addingTimeInterval(15)
        while Date() < readinessDeadline {
            if let snapshot = usage.snapshots[target.session.id],
               (snapshot.candidateCount ?? 0) > 0 || snapshot.status == "available" {
                break
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
        guard let ready = usage.snapshots[target.session.id],
              (ready.candidateCount ?? 0) > 0 || ready.status == "available" else {
            emit("Test \(number) FAIL — Codex process was not detected for \(target.group.name) within 15 seconds.")
            return false
        }

        let baselineInput = ready.inputTokens ?? 0
        let baselineOutput = ready.outputTokens ?? 0
        emit("Baseline header: \(summary(ready))")
        let prompt = "hello world!"
        target.session.terminal.sendTestSubmission(prompt)
        emit("Submitted the requested test text through GridlineTerminalView.send(Enter); chars=\(prompt.unicodeScalars.count), pasted=0. Prompt stored in the local Debug timeline.")

        let deadline = Date().addingTimeInterval(responseCheckWindow)
        var lastSnapshot: TerminalUsageSnapshot?
        var lastCounts: (Int, Int, Int)?
        var stablePolls = 0
        while Date() < deadline {
            let snapshot = usage.snapshots[target.session.id]
            if let snapshot,
               snapshot.status == "available",
               let input = snapshot.inputTokens,
               let output = snapshot.outputTokens,
               let total = snapshot.totalTokens,
               input > baselineInput,
               output > baselineOutput,
               isResolved(snapshot.submissionResolution) {
                let counts = (input, output, total)
                if let previous = lastCounts,
                   previous.0 == counts.0, previous.1 == counts.1, previous.2 == counts.2 {
                    stablePolls += 1
                } else {
                    stablePolls = 1
                }
                lastCounts = counts
                lastSnapshot = snapshot
                if stablePolls >= 2 {
                    emit("Test \(number) PASS — response usage populated and stayed stable across two polls: \(summary(snapshot))")
                    return true
                }
            } else {
                stablePolls = 0
                lastCounts = nil
                lastSnapshot = snapshot
            }
            try? await Task.sleep(nanoseconds: 3_000_000_000)
        }

        let finalSnapshot = usage.snapshots[target.session.id] ?? lastSnapshot
        emit("Test \(number) FAIL — IN/OUT did not become matched, nonzero, and stable within 15 seconds.")
        emit("Last header state: \(finalSnapshot.map(summary) ?? "IN — · OUT — · TOTAL —")")
        return false
    }

    private func target(containing marker: String) -> Target? {
        for group in workspace.groups where group.name.localizedCaseInsensitiveContains(marker) {
            if let session = workspace.groupSessions(group).first(where: { $0.kind == .codex }) {
                return Target(group: group, session: session)
            }
        }
        return nil
    }

    private func summary(_ snapshot: TerminalUsageSnapshot) -> String {
        "IN \(count(snapshot.inputTokens)) · OUT \(count(snapshot.outputTokens)) · TOTAL \(count(snapshot.totalTokens)) · status=\(snapshot.status) · resolution=\(snapshot.submissionResolution ?? "none")"
    }

    private func isResolved(_ resolution: String?) -> Bool {
        guard let resolution else { return false }
        return resolution != "awaiting_provider_update" && resolution != "competing_terminal_submissions"
    }

    private func count(_ value: Int?) -> String {
        guard let value else { return "—" }
        return value.formatted(.number)
    }

    private func emit(_ message: String) {
        print(message)
        guard let reportURL,
              let handle = try? FileHandle(forWritingTo: reportURL) else { return }
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: Data((message + "\n").utf8))
    }
}
