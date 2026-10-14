import AppKit
import Darwin
import Foundation

enum DebugEvents {
    static let directory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("gridline_debug", isDirectory: true)

    private static let lock = NSLock()
    private static let retainedEventCount = 500
    private static let maximumEventLogBytes = 512 * 1024
    private struct PendingTerminalSubmission {
        let id: String
        let submittedAt: Date
        let typedCharacters: Int
        let pastedCharacters: Int
    }
    private static var pendingSubmissions: [String: [PendingTerminalSubmission]] = [:]

    /// Detailed diagnostics are collected only while this app copy's paired inspector is open.
    static var isInspectorOpen: Bool {
        guard let appID = Bundle.main.bundleIdentifier else { return false }
        let inspectorID = appID
            .replacingOccurrences(of: "local.gridline.terminal", with: "local.myllm.debuginspector")
        return NSRunningApplication.runningApplications(withBundleIdentifier: inspectorID)
            .contains { !$0.isTerminated }
    }

    static func resetEventLogForAppLaunch() {
        lock.lock()
        defer { lock.unlock() }
        pendingSubmissions.removeAll()
        try? FileManager.default.removeItem(at: directory.appendingPathComponent("events.jsonl"))
        try? FileManager.default.removeItem(at: directory.appendingPathComponent("timeline.jsonl"))
    }

    static func record(_ name: String, element: String, details: [String: String] = [:]) {
        let entry: [String: Any] = [
            "time": ISO8601DateFormatter().string(from: Date()),
            "app": "Gridline",
            "event": name,
            "element": element,
            "details": details
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: entry, options: [.sortedKeys]),
              let line = String(data: data, encoding: .utf8)?.appending("\n") else { return }
        lock.lock()
        defer { lock.unlock() }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("events.jsonl")
            if FileManager.default.fileExists(atPath: url.path),
               let file = try? FileHandle(forWritingTo: url) {
                try file.seekToEnd()
                try file.write(contentsOf: Data(line.utf8))
                try file.close()
            } else {
                try Data(line.utf8).write(to: url, options: .atomic)
            }
            if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
               ((attributes[.size] as? NSNumber)?.intValue ?? 0) > maximumEventLogBytes,
               let contents = try? String(contentsOf: url, encoding: .utf8) {
                let recent = contents.split(separator: "\n").suffix(retainedEventCount)
                try (recent.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
            }
        } catch {
            // Debug capture must never interrupt normal app behavior.
        }
    }

    static func recordDiagnostic(_ name: String, element: String, details: [String: String] = [:]) {
        guard isInspectorOpen else { return }
        record(name, element: element, details: details)
    }

    static func recordTerminalSubmission(
        sessionID: UUID,
        groupID: UUID,
        groupName: String,
        kind: String,
        typedCharacterCount: Int,
        pastedCharacterCount: Int,
        submittedText: String
    ) {
        let typed = max(0, typedCharacterCount)
        let pasted = max(0, pastedCharacterCount)
        let submissionID = UUID().uuidString
        lock.lock()
        var pending = pendingSubmissions[sessionID.uuidString, default: []]
        pending.removeAll { Date().timeIntervalSince($0.submittedAt) > 1800 }
        pending.append(PendingTerminalSubmission(
            id: submissionID,
            submittedAt: Date(),
            typedCharacters: typed,
            pastedCharacters: pasted
        ))
        pendingSubmissions[sessionID.uuidString] = Array(pending.suffix(20))
        lock.unlock()
        recordDiagnostic("terminal.inputSubmitted", element: "gridline.session.terminal.\(sessionID.uuidString)", details: [
            "submissionID": submissionID,
            "session": sessionID.uuidString,
            "groupID": groupID.uuidString,
            "groupName": groupName,
            "kind": kind,
            "characterCount": String(typed + pasted),
            "typedCharacterCount": String(typed),
            "pastedCharacterCount": String(pasted),
            "countUnit": "unicode_scalars",
            "pipeline": "Workspace.swift:GridlineTerminalView.insertText/paste/send > DebugEvents.swift:recordTerminalSubmission; awaiting ProviderUsageService.swift:TerminalUsageStatus.apply > usage/terminal_usage.py"
        ])
        recordSubmittedPrompt(
            submittedText,
            submissionID: submissionID,
            sessionID: sessionID,
            groupName: groupName,
            kind: kind
        )
    }

    private static func recordSubmittedPrompt(
        _ prompt: String,
        submissionID: String,
        sessionID: UUID,
        groupName: String,
        kind: String
    ) {
        guard kind == "codex", isInspectorOpen, !prompt.isEmpty else { return }
        let entry: [String: Any] = [
            "time": ISO8601DateFormatter().string(from: Date()),
            "app": "Gridline",
            "event": "prompt.submitted",
            "element": "gridline.session.terminal.\(sessionID.uuidString)",
            "details": [
                "groupName": groupName,
                "session": sessionID.uuidString,
                "submissionID": submissionID,
                "prompt": prompt,
                "kind": kind
            ]
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: entry, options: [.sortedKeys]) else { return }
        let url = directory.appendingPathComponent("timeline.jsonl")
        let descriptor = Darwin.open(url.path, O_WRONLY | O_APPEND | O_CREAT, 0o600)
        guard descriptor >= 0 else { return }
        defer { Darwin.close(descriptor) }
        let bytes = Array(data) + [UInt8(0x0A)]
        bytes.withUnsafeBytes { buffer in
            guard let base = buffer.baseAddress else { return }
            _ = Darwin.write(descriptor, base, buffer.count)
        }
    }

    static func consumePendingSubmission(sessionID: String, usageUpdatedAt: String?) -> [String: String]? {
        guard let usageUpdatedAt, let usageDate = parseISO8601(usageUpdatedAt) else { return nil }
        lock.lock()
        defer { lock.unlock() }
        guard var pending = pendingSubmissions[sessionID],
              let index = pending.firstIndex(where: { $0.submittedAt <= usageDate.addingTimeInterval(2) }) else { return nil }
        let submission = pending.remove(at: index)
        pendingSubmissions[sessionID] = pending
        return [
            "submissionID": submission.id,
            "submittedCharacterCount": String(submission.typedCharacters + submission.pastedCharacters),
            "submittedTypedCharacterCount": String(submission.typedCharacters),
            "submittedPastedCharacterCount": String(submission.pastedCharacters),
            "submissionPipeline": "Workspace.swift:GridlineTerminalView.send(Enter) > DebugEvents.swift:recordTerminalSubmission > ProviderUsageService.swift:TerminalUsageStatus.apply > usage/terminal_usage.py:consume_codex/consume_claude"
        ]
    }

    private static func parseISO8601(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value) ?? {
            formatter.formatOptions = [.withInternetDateTime]
            return formatter.date(from: value)
        }()
    }

    static func configurePythonProcess(
        _ process: Process,
        workflow: String,
        script: String,
        swiftStage: String
    ) {
        let tracing = isInspectorOpen
        var environment = process.environment ?? ProcessInfo.processInfo.environment
        environment["GRIDLINE_DEBUG_TRACE"] = tracing ? "1" : nil
        if let runtime = Bundle.main.resourceURL?.appendingPathComponent("runtime", isDirectory: true) {
            let existing = environment["PYTHONPATH"].map { ":\($0)" } ?? ""
            environment["PYTHONPATH"] = runtime.path + existing
        }
        process.environment = environment

        guard tracing else {
            process.standardError = FileHandle.nullDevice
            return
        }
        recordDiagnostic("runtime.pythonProcess", element: script, details: [
            "workflow": workflow,
            "language": "Swift",
            "stage": swiftStage,
            "status": "started",
            "pipeline": "\(swiftStage) > \(script)"
        ])
        let pipe = Pipe()
        process.standardError = pipe
        let decoder = PythonTraceLineBuffer(workflow: workflow, script: script, swiftStage: swiftStage)
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                handle.readabilityHandler = nil
                return
            }
            for row in decoder.append(data) {
                recordDiagnostic(row.event, element: script, details: row.details)
            }
        }
    }

    static func recordExternalProcess(
        workflow: String,
        executable: String,
        stage: String,
        status: String,
        exitCode: Int32? = nil
    ) {
        // Polling commands run repeatedly during normal monitoring. Keep the
        // event log useful by recording only failed native commands.
        guard isInspectorOpen, status == "failed" else { return }
        var details = [
            "workflow": workflow,
            "language": "Swift",
            "stage": stage,
            "status": status,
            "pipeline": "\(stage) > \(executable)"
        ]
        if let exitCode { details["exitCode"] = String(exitCode) }
        record("runtime.externalProcess", element: executable, details: details)
    }

    static func recordPythonProcessFinished(
        workflow: String,
        script: String,
        swiftStage: String,
        exitCode: Int32
    ) {
        recordDiagnostic("runtime.pythonProcess", element: script, details: [
            "workflow": workflow,
            "language": "Swift",
            "stage": swiftStage,
            "status": exitCode == 0 ? "completed" : "failed",
            "exitCode": String(exitCode),
            "pipeline": "\(swiftStage) > \(script)"
        ])
    }
}

private final class PythonTraceLineBuffer {
    private let workflow: String
    private let script: String
    private let swiftStage: String
    private var buffer = Data()

    init(workflow: String, script: String, swiftStage: String) {
        self.workflow = workflow
        self.script = script
        self.swiftStage = swiftStage
    }

    struct Event {
        let event: String
        let details: [String: String]
    }

    func append(_ data: Data) -> [Event] {
        buffer.append(data)
        var rows: [Event] = []
        while let newline = buffer.firstRange(of: Data([0x0A])) {
            let line = buffer[..<newline.lowerBound]
            buffer.removeSubrange(..<newline.upperBound)
            guard let text = String(data: line, encoding: .utf8) else { continue }
            if text.hasPrefix("GRIDLINE_DEBUG ") {
                guard let json = text.dropFirst("GRIDLINE_DEBUG ".count).data(using: .utf8),
                      let row = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
                      let feature = row["feature"] as? String,
                      let prefix = row["prefix"] as? String else { continue }
                var details = [
                    "workflow": workflow,
                    "language": "Python",
                    "feature": feature,
                    "featurePrefix": prefix,
                    "message": row["message"] as? String ?? "debug event",
                    "pipeline": "\(swiftStage) > \(script):debug_event"
                ]
                if let groupName = row["groupName"] as? String { details["groupName"] = groupName }
                if let session = row["session"] as? String { details["providerSession"] = session }
                if let counts = row["counts"] as? [String: Int] {
                    details["counts"] = counts.sorted { $0.key < $1.key }
                        .map { "\($0.key)=\($0.value)" }
                        .joined(separator: ",")
                }
                rows.append(Event(event: "runtime.pythonDebug", details: details))
                continue
            }
            guard text.hasPrefix("GRIDLINE_TRACE "),
                  let json = text.dropFirst("GRIDLINE_TRACE ".count).data(using: .utf8),
                  let row = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
                  row["workflow"] as? String == workflow,
                  let stage = row["stage"] as? String,
                  let status = row["status"] as? String else { continue }
            var details = [
                "workflow": workflow,
                "language": "Python",
                "stage": stage,
                "status": status,
                "pipeline": "\(swiftStage) > \(script):\(stage)"
            ]
            if let errorType = row["errorType"] as? String { details["errorType"] = errorType }
            if let counts = row["counts"] as? [String: Int] {
                details["counts"] = counts.sorted { $0.key < $1.key }
                    .map { "\($0.key)=\($0.value)" }
                    .joined(separator: ",")
            }
            rows.append(Event(event: "runtime.pythonStage", details: details))
        }
        return rows
    }
}
