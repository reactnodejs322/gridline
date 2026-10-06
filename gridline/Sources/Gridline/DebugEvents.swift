import Foundation

enum DebugEvents {
    static let directory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("gridline_debug", isDirectory: true)

    private static let lock = NSLock()
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
        } catch {
            // Debug capture must never interrupt normal app behavior.
        }
    }
}
