import AVFoundation
import AppKit
import SwiftUI

@MainActor
final class VoiceTodoModel: ObservableObject {
    @Published var text = "" {
        didSet { UserDefaults.standard.set(text, forKey: Self.savedNoteKey) }
    }
    @Published var status = "Waiting for “OK, problem”. Say “OK, next problem” to start another bullet."
    @Published var isListening = false
    @Published var isStopping = false
    @Published var isEdited = false
    @Published var chunkCount = 0
    @Published var audioLevel: CGFloat = 0
    @Published var waveform = Array(repeating: CGFloat(0.035), count: 44)
    @Published var wakePhraseConfidence: Int?
    @Published var wakePhraseText: String?
    @Published var wakePhraseDetected = false
    @Published var wakeConfidenceThreshold = 55

    private let engine = AVAudioEngine()
    private var worker: Process?
    private var pollTimer: Timer?
    private var queueURL: URL?
    private var samples: [Int16] = []
    private var chunkIndex = 0
    private var recognizedChunks: [Int: String] = [:]
    private var wakeConfidenceByChunk: [Int: Int] = [:]
    private var sessionBaseText = ""
    private var manualBoundaries: [Int] = []
    private var lastFormattedText = ""
    private let chunkSampleCount = 16_000 * 5
    private static let savedNoteKey = "gridline.voiceTodo.latestProblemNote"

    init() {
        text = UserDefaults.standard.string(forKey: Self.savedNoteKey) ?? ""
        sessionBaseText = text
        let stored = UserDefaults.standard.integer(forKey: "gridline.voiceTodo.wakeConfidenceThreshold")
        if stored > 0 { wakeConfidenceThreshold = min(90, max(20, stored)) }
    }

    func startListening() {
        guard !isListening, !isStopping else { return }
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            beginCapture()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                Task { @MainActor in
                    guard let self else { return }
                    if granted { self.beginCapture() }
                    else { self.status = "Microphone access is off. Enable it for Gridline in System Settings → Privacy & Security → Microphone." }
                }
            }
        default:
            status = "Microphone access is off. Enable it for Gridline in System Settings → Privacy & Security → Microphone."
        }
    }

    func endProblem() {
        guard isListening, wakePhraseDetected else { return }
        if !samples.isEmpty { writeChunk(samples); samples.removeAll(keepingCapacity: true) }
        manualBoundaries.append(chunkIndex)
        status = "Problem boundary marked. Keep speaking; the next words start a new bullet."
        DebugEvents.record("voiceTodo.problemEnded", element: "gridline.voiceTodo.endProblem")
    }

    func stopListening() {
        guard isListening else { return }
        isListening = false
        isStopping = true
        status = "Finishing the last speech chunk…"
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        audioLevel = 0
        waveform = Array(repeating: CGFloat(0.035), count: 44)
        if !samples.isEmpty { writeChunk(samples); samples.removeAll(keepingCapacity: true) }
        if let queueURL { try? Data().write(to: queueURL.appendingPathComponent("STOP"), options: .atomic) }
        DebugEvents.record("voiceTodo.listeningStopped", element: "gridline.voiceTodo.stop")
        finishWhenWorkerStops()
    }

    func clear() {
        text = ""
        sessionBaseText = ""
        isEdited = false
        recognizedChunks.removeAll()
        wakeConfidenceByChunk.removeAll()
        manualBoundaries.removeAll()
        lastFormattedText = ""
        wakePhraseConfidence = nil
        wakePhraseText = nil
        wakePhraseDetected = false
        status = "Waiting for “OK, problem”. Say “OK, next problem” to start another bullet."
    }

    func userEdited(_ value: String) {
        text = value
        isEdited = true
    }

    func adjustWakeConfidenceThreshold(by amount: Int) {
        wakeConfidenceThreshold = min(90, max(20, wakeConfidenceThreshold + amount))
        UserDefaults.standard.set(wakeConfidenceThreshold, forKey: "gridline.voiceTodo.wakeConfidenceThreshold")
        DebugEvents.record("voiceTodo.confidenceThresholdChanged", element: "gridline.voiceTodo.confidenceThreshold", details: [
            "threshold": String(wakeConfidenceThreshold)
        ])
        let parsed = VoiceTodoFormatting.parse(
            chunks: recognizedChunks,
            wakeConfidenceByChunk: wakeConfidenceByChunk,
            minimumConfidence: wakeConfidenceThreshold,
            manualBoundaries: manualBoundaries
        )
        wakePhraseDetected = parsed.isStarted
        lastFormattedText = parsed.text
        if !isEdited { text = combinedNote(parsed.text) }
        if let wakePhraseConfidence {
            status = wakePhraseConfidence >= wakeConfidenceThreshold
                ? "Wake phrase meets the \(wakeConfidenceThreshold)% threshold."
                : "Wake phrase is below the \(wakeConfidenceThreshold)% threshold and is ignored."
        } else {
            status = "Wake phrases below \(wakeConfidenceThreshold)% are ignored."
        }
    }

    func shutdown() {
        if isListening { stopListening() }
        pollTimer?.invalidate()
        worker?.terminate()
        worker = nil
        if let queueURL { try? FileManager.default.removeItem(at: queueURL) }
    }

    private func beginCapture() {
        guard let skillRoot = Bundle.main.resourceURL?.appendingPathComponent("skill_script", isDirectory: true) else {
            status = "The bundled skill_script folder is missing."
            return
        }
        let script = skillRoot.appendingPathComponent("voice_todo/voice_todo.py")
        let model = skillRoot.appendingPathComponent("resources/models/whisper-small-mlx", isDirectory: true)
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Gridline/skill_script/python-packages", isDirectory: true)
        let python = ["/opt/homebrew/bin/python3", "/usr/local/bin/python3"]
            .map { URL(fileURLWithPath: $0) }
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
        guard FileManager.default.fileExists(atPath: script.path),
              FileManager.default.fileExists(atPath: model.appendingPathComponent("weights.npz").path),
              FileManager.default.fileExists(atPath: support.path), let python else {
            status = "Voice todo's local model or Python packages are missing. Check skill_script/resources/models and audio_to_text/requirements.txt."
            return
        }

        let queue = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("gridline-voice-todo-\(UUID().uuidString)", isDirectory: true)
        do { try FileManager.default.createDirectory(at: queue, withIntermediateDirectories: true) }
        catch { status = "Could not prepare the temporary voice queue: \(error.localizedDescription)"; return }
        queueURL = queue
        isEdited = false
        sessionBaseText = text
        recognizedChunks.removeAll()
        wakeConfidenceByChunk.removeAll()
        manualBoundaries.removeAll()
        lastFormattedText = ""
        wakePhraseConfidence = nil
        wakePhraseText = nil
        wakePhraseDetected = false
        chunkCount = 0
        chunkIndex = 0
        samples.removeAll(keepingCapacity: true)
        audioLevel = 0
        waveform = Array(repeating: CGFloat(0.035), count: 44)

        let process = Process()
        process.executableURL = python
        process.arguments = [script.path, queue.path, model.path]
        var environment = ProcessInfo.processInfo.environment
        environment["PYTHONPATH"] = support.path
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        process.environment = environment
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do { try process.run() }
        catch { status = "Could not start the local Whisper worker: \(error.localizedDescription)"; return }
        worker = process

        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            process.terminate()
            status = "No microphone input is available."
            return
        }
        input.installTap(onBus: 0, bufferSize: 2_048, format: format) { [weak self] buffer, _ in
            guard let self, let channels = buffer.floatChannelData else { return }
            let rate = format.sampleRate
            let frames = Int(buffer.frameLength)
            let channelCount = Int(format.channelCount)
            let converted = (0..<Int(Double(frames) * 16_000 / rate)).map { outputIndex -> Int16 in
                let sourceIndex = min(frames - 1, Int(Double(outputIndex) * rate / 16_000))
                var mixed: Float = 0
                for channel in 0..<channelCount { mixed += channels[channel][sourceIndex] }
                mixed /= Float(channelCount)
                return Int16(max(-1, min(1, mixed)) * Float(Int16.max))
            }
            let rms = converted.isEmpty ? 0 : sqrt(
                converted.reduce(0.0) { $0 + Double($1) * Double($1) } / Double(converted.count)
            ) / Double(Int16.max)
            Task { @MainActor [weak self] in
                guard let self else { return }
                let visibleLevel = min(1, CGFloat(rms * 12))
                self.audioLevel = visibleLevel
                self.waveform.append(max(0.035, visibleLevel))
                if self.waveform.count > 44 { self.waveform.removeFirst(self.waveform.count - 44) }
                self.samples.append(contentsOf: converted)
                while self.samples.count >= self.chunkSampleCount {
                    let chunk = Array(self.samples.prefix(self.chunkSampleCount))
                    self.samples.removeFirst(self.chunkSampleCount)
                    self.writeChunk(chunk)
                }
            }
        }
        do {
            try engine.start()
            isListening = true
            isStopping = false
            status = "Listening live. Speak “OK, problem”; recognized words will appear here as they arrive."
            DebugEvents.record("voiceTodo.listeningStarted", element: "gridline.voiceTodo.start")
            pollTimer?.invalidate()
            pollTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] _ in
                guard let model = self else { return }
                Task { @MainActor [weak model] in model?.readAvailableResults() }
            }
        } catch {
            input.removeTap(onBus: 0)
            process.terminate()
            status = "Could not start microphone capture: \(error.localizedDescription)"
        }
    }

    private func writeChunk(_ chunk: [Int16]) {
        guard let queueURL else { return }
        guard containsClearVoice(chunk) else {
            if !isEdited { status = "No clear speech in that chunk. Check the mic level and speak toward the microphone." }
            return
        }
        let index = chunkIndex
        chunkIndex += 1
        var data = Data()
        data.append(contentsOf: Array("RIFF".utf8))
        data.appendLE(UInt32(36 + chunk.count * 2))
        data.append(contentsOf: Array("WAVEfmt ".utf8))
        data.appendLE(UInt32(16)); data.appendLE(UInt16(1)); data.appendLE(UInt16(1))
        data.appendLE(UInt32(16_000)); data.appendLE(UInt32(32_000)); data.appendLE(UInt16(2)); data.appendLE(UInt16(16))
        data.append(contentsOf: Array("data".utf8)); data.appendLE(UInt32(chunk.count * 2))
        for sample in chunk { data.appendLE(UInt16(bitPattern: sample)) }
        let destination = queueURL.appendingPathComponent(String(format: "chunk-%06d.wav", index))
        try? data.write(to: destination, options: .atomic)
    }

    private func containsClearVoice(_ samples: [Int16]) -> Bool {
        let frameLength = 320 // 20 ms at 16 kHz
        var activeFrames = 0
        var peak = 0
        for start in stride(from: 0, to: samples.count, by: frameLength) {
            let end = min(samples.count, start + frameLength)
            guard end > start else { continue }
            var energy = 0.0
            for sample in samples[start..<end] {
                let magnitude = abs(Int(sample))
                peak = max(peak, magnitude)
                energy += Double(sample) * Double(sample)
            }
            let rms = sqrt(energy / Double(end - start)) / Double(Int16.max)
            if rms >= 0.012 { activeFrames += 1 }
        }
        return activeFrames >= 6 && peak >= 700
    }

    private func readAvailableResults() {
        guard let queueURL else { return }
        let files = (try? FileManager.default.contentsOfDirectory(at: queueURL, includingPropertiesForKeys: nil)) ?? []
        for file in files where file.lastPathComponent.hasPrefix("result-") && file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file),
                  let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let index = result["index"] as? Int else { continue }
            if let error = result["error"] as? String {
                status = "Local transcription error: \(error)"
            } else {
                if let confidence = result["wake_phrase_confidence"] as? Int {
                    wakePhraseConfidence = confidence
                    wakeConfidenceByChunk[index] = confidence
                    wakePhraseText = result["wake_phrase"] as? String
                }
                if let recognized = result["text"] as? String, !recognized.isEmpty {
                    recognizedChunks[index] = recognized
                    chunkCount = recognizedChunks.count
                    let parsed = VoiceTodoFormatting.parse(
                        chunks: recognizedChunks,
                        wakeConfidenceByChunk: wakeConfidenceByChunk,
                        minimumConfidence: wakeConfidenceThreshold,
                        manualBoundaries: manualBoundaries
                    )
                    if isEdited {
                        if parsed.text.hasPrefix(lastFormattedText) {
                            let addition = String(parsed.text.dropFirst(lastFormattedText.count))
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                            if !addition.isEmpty { text += (text.isEmpty ? "" : "\n") + addition }
                        }
                    } else {
                        text = combinedNote(parsed.text)
                    }
                    lastFormattedText = parsed.text
                    wakePhraseDetected = parsed.isStarted
                    if parsed.isStarted {
                        status = "Wake phrase accepted · speech is being added to Problem Notes."
                    } else if let confidence = wakePhraseConfidence, let phrase = wakePhraseText {
                        status = "“\(phrase)” scored \(confidence)% · \(confidence >= wakeConfidenceThreshold ? "accepted" : "below threshold; ignored")."
                    } else if !isEdited {
                        status = "Waiting for “OK, problem” or “OK, next problem”. Other speech stays out of Problem Notes."
                    }
                } else if result["no_speech"] as? Bool == true, !isEdited {
                    status = wakePhraseDetected
                        ? "No clear speech detected. The wake phrase was heard; waiting for the problem details."
                        : "No clear speech detected. Check the mic level; still waiting for the wake phrase."
                }
            }
            try? FileManager.default.removeItem(at: file)
        }
        let errorFile = queueURL.appendingPathComponent("worker-error.txt")
        if let error = try? String(contentsOf: errorFile, encoding: .utf8) {
            status = "Local Whisper worker failed: \(error)"
        }
        if isStopping, let worker, !worker.isRunning {
            readAvailableResultsOnce(queueURL)
            pollTimer?.invalidate(); pollTimer = nil
            self.worker = nil
            isStopping = false
            status = text.isEmpty
                ? "No clear speech was captured. Check the mic level and try speaking closer."
                : "Listening stopped. Your recognized text is ready to edit or copy."
            try? FileManager.default.removeItem(at: queueURL)
            self.queueURL = nil
        }
    }

    private func readAvailableResultsOnce(_ directory: URL) {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        for file in files where file.lastPathComponent.hasPrefix("result-") && file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file),
                  let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let index = result["index"] as? Int, let recognized = result["text"] as? String else { continue }
            recognizedChunks[index] = recognized
            if let confidence = result["wake_phrase_confidence"] as? Int {
                wakePhraseConfidence = confidence
                wakeConfidenceByChunk[index] = confidence
                wakePhraseText = result["wake_phrase"] as? String
            }
        }
        let parsed = VoiceTodoFormatting.parse(
            chunks: recognizedChunks,
            wakeConfidenceByChunk: wakeConfidenceByChunk,
            minimumConfidence: wakeConfidenceThreshold,
            manualBoundaries: manualBoundaries
        )
        wakePhraseDetected = parsed.isStarted
        if !isEdited { text = combinedNote(parsed.text) }
    }

    private func finishWhenWorkerStops() {
        readAvailableResults()
        if isStopping {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                Task { @MainActor in self?.finishWhenWorkerStops() }
            }
        }
    }

    private func combinedNote(_ capturedText: String) -> String {
        guard !capturedText.isEmpty else { return sessionBaseText }
        guard !sessionBaseText.isEmpty else { return capturedText }
        return sessionBaseText + "\n\n" + capturedText
    }
}

private enum VoiceTodoFormatting {
    struct Parsed {
        let text: String
        let isStarted: Bool
    }

    static func parse(
        chunks: [Int: String],
        wakeConfidenceByChunk: [Int: Int],
        minimumConfidence: Int,
        manualBoundaries: [Int]
    ) -> Parsed {
        let manual = Set(manualBoundaries)
        let cuePattern = #"(?i)\b(?:(?:okay|ok)[, .!?:;-]*(?:next[, .!?:;-]*)?|next[, .!?:;-]*)problem\b"#
        let cueRegex = try? NSRegularExpression(pattern: cuePattern)
        let raw = chunks.keys.sorted().map { index in
            let original = chunks[index] ?? ""
            let confidence = wakeConfidenceByChunk[index] ?? -1
            let text: String
            if confidence >= minimumConfidence {
                text = original
            } else if let cueRegex {
                let range = NSRange(original.startIndex..., in: original)
                text = cueRegex.stringByReplacingMatches(in: original, range: range, withTemplate: " ")
            } else {
                text = original
            }
            return (manual.contains(index) ? "\u{E000} " : "") + text
        }.joined(separator: " ")
            .replacingOccurrences(of: "\n", with: " ")
        let pattern = #"\uE000|\b(?:(?:okay|ok)[, .!?:;-]*(?:next[, .!?:;-]*)?|next[, .!?:;-]*)problem\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return Parsed(text: "", isStarted: false) }
        let matches = regex.matches(in: raw, range: NSRange(raw.startIndex..., in: raw))
        guard !matches.isEmpty else { return Parsed(text: "", isStarted: false) }
        var bullets: [String] = []
        var current = ""
        var cursor = raw.startIndex
        var startedByCue = false
        for match in matches {
            guard let range = Range(match.range, in: raw) else { continue }
            let words = String(raw[cursor..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            if startedByCue, !words.isEmpty {
                if current.isEmpty { current = words }
                else { current += " " + words }
            }
            let marker = String(raw[range])
            if marker == "\u{E000}" {
                if !startedByCue, !words.isEmpty { current = words }
                if !current.isEmpty { bullets.append(current); current = "" }
                startedByCue = true
            } else {
                if !current.isEmpty { bullets.append(current); current = "" }
                startedByCue = true
            }
            cursor = range.upperBound
        }
        let tail = String(raw[cursor...]).trimmingCharacters(in: .whitespacesAndNewlines)
        if startedByCue, !tail.isEmpty { current = current.isEmpty ? tail : current + " " + tail }
        if !current.isEmpty { bullets.append(current) }
        let formatted = bullets.filter { !$0.isEmpty }.map { "• \($0)" }.joined(separator: "\n\n")
        return Parsed(text: formatted, isStarted: startedByCue)
    }
}

private extension Data {
    mutating func appendLE<T: FixedWidthInteger>(_ value: T) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
    }
}

struct VoiceTodoModalView: View {
    @EnvironmentObject private var templateStore: GridlineTemplateStore
    @ObservedObject var model: VoiceTodoModel
    let onClose: () -> Void
    @State private var didCopy = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea()
            VStack(spacing: 0) {
                header
                Divider().overlay(Color.white.opacity(0.07))
                transcriptEditor
                    .padding(.horizontal, 24).padding(.top, 18)
                    .frame(minHeight: 200, maxHeight: .infinity)
                HStack(spacing: 8) {
                    Image(systemName: model.isListening ? "waveform" : "info.circle")
                        .foregroundStyle(model.isListening ? Color.mint : Color.secondary)
                    Text(model.status).lineLimit(1).truncationMode(.tail)
                    Spacer(minLength: 12)
                    if model.chunkCount > 0 {
                        Text("\(model.chunkCount) CHUNKS")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(.tertiary).tracking(0.4)
                    }
                }
                .font(.system(size: 10)).foregroundStyle(.secondary)
                .padding(.horizontal, 25).padding(.top, 11)
                WakePhraseConfidenceControl(
                    confidence: model.wakePhraseConfidence,
                    phrase: model.wakePhraseText,
                    threshold: model.wakeConfidenceThreshold,
                    onAdjust: { model.adjustWakeConfidenceThreshold(by: $0) }
                )
                .padding(.horizontal, 24).padding(.top, 8)
                VoiceTodoInputMeter(
                    level: model.audioLevel,
                    waveform: model.waveform,
                    isListening: model.isListening
                )
                .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 14)
                Divider().overlay(Color.white.opacity(0.06))
                HStack(spacing: 9) {
                    if model.isListening {
                        VoiceTodoControlButton(title: "End problem", icon: "text.badge.checkmark", kind: .quiet, isEnabled: model.wakePhraseDetected) { model.endProblem() }
                            .accessibilityIdentifier("gridline.voiceTodo.endProblem")
                        VoiceTodoControlButton(title: "Stop listening", icon: "stop.fill", kind: .danger) { model.stopListening() }
                            .accessibilityIdentifier("gridline.voiceTodo.stop")
                    } else {
                        VoiceTodoControlButton(title: "Start listening", icon: "mic.fill", kind: .primary, isEnabled: !model.isStopping) { model.startListening() }
                            .accessibilityIdentifier("gridline.voiceTodo.start")
                        if !model.text.isEmpty {
                            VoiceTodoControlButton(title: didCopy ? "Copied" : "Copy text", icon: didCopy ? "checkmark" : "doc.on.doc", kind: .quiet) {
                                NSPasteboard.general.clearContents(); NSPasteboard.general.setString(model.text, forType: .string)
                                didCopy = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { didCopy = false }
                            }
                            .accessibilityIdentifier("gridline.voiceTodo.copy")
                            Button("Clear saved note") { model.clear() }
                                .font(.system(size: 10, weight: .medium)).buttonStyle(.plain).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button(action: onClose) {
                        Text("Done")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 14).frame(height: 34)
                    }.buttonStyle(.plain)
                }
                .padding(.horizontal, 24).padding(.vertical, 17)
            }
            .frame(width: 740, height: 610)
            .background(templateStore.activeTemplate.palette.elevatedSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1))
            .shadow(color: .black.opacity(0.55), radius: 35, y: 18)
            .accessibilityIdentifier("gridline.voiceTodo.modal")
        }
        .onDisappear { model.shutdown() }
    }

    private var header: some View {
        HStack(spacing: 13) {
            Image(systemName: "waveform.badge.mic")
                .font(.system(size: 18, weight: .semibold)).foregroundStyle(Color.mint)
                .frame(width: 42, height: 42)
                .background(Color.mint.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 4) {
                Text("Voice todo").font(.system(size: 16, weight: .semibold))
                Text("Live capture · local transcription")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 6) {
                Circle().fill(model.isListening ? Color.mint : Color.white.opacity(0.26)).frame(width: 6, height: 6)
                Text(model.isListening ? "LIVE" : model.isStopping ? "FINISHING" : "READY")
                    .font(.system(size: 8, weight: .bold, design: .monospaced)).tracking(0.7)
                    .foregroundStyle(model.isListening ? Color.mint : Color.secondary)
                    .accessibilityIdentifier("gridline.voiceTodo.status")
            }
            .padding(.horizontal, 9).frame(height: 24)
            .background(Color.white.opacity(0.045), in: Capsule())
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary)
                    .frame(width: 30, height: 30).background(Color.white.opacity(0.06), in: Circle())
            }
            .buttonStyle(.plain).accessibilityIdentifier("gridline.voiceTodo.close")
        }
        .padding(.horizontal, 24).padding(.vertical, 17)
    }

    private var transcriptEditor: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("PROBLEM NOTES")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(0.8).foregroundStyle(.secondary)
                Spacer()
                Text(model.text.isEmpty ? "WAITING FOR CUE" : "SAVED DRAFT · \(model.text.split(whereSeparator: \.isNewline).count) LINES")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.mint.opacity(0.8))
            }
            ZStack(alignment: .topLeading) {
                TextEditor(text: Binding(get: { model.text }, set: model.userEdited))
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Color(red: 0.91, green: 0.93, blue: 0.94))
                    .scrollContentBackground(.hidden)
                    .padding(11)
                    .accessibilityLabel("Editable voice todo transcript")
                    .accessibilityIdentifier("gridline.voiceTodo.input")
                if model.text.isEmpty {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Your problem notes will appear here")
                            .font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                    Text("Nothing enters notes until “OK, problem” is recognized. Say “OK, next problem” or tap End problem to start another bullet.")
                            .font(.system(size: 10)).foregroundStyle(.tertiary).lineSpacing(3)
                    }
                    .padding(.horizontal, 17).padding(.top, 17).allowsHitTesting(false)
                }
            }
            .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.white.opacity(0.075), lineWidth: 1))
            .frame(minHeight: 155, maxHeight: .infinity)
        }
    }
}

private struct VoiceTodoInputMeter: View {
    let level: CGFloat
    let waveform: [CGFloat]
    let isListening: Bool

    var body: some View {
        VStack(spacing: 9) {
            HStack {
                Text("MIC INPUT")
                    .font(.system(size: 8, weight: .bold, design: .monospaced)).tracking(0.8)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(isListening ? "LEVEL \(Int(level * 100))% · SPEECH GATE ~15%" : "SPEAK TO CHECK LEVEL")
                    .font(.system(size: 8, weight: .medium, design: .monospaced)).tracking(0.3)
                    .foregroundStyle(isListening ? Color.mint.opacity(0.9) : Color.secondary)
            }
            HStack(alignment: .center, spacing: 3) {
                ForEach(Array(waveform.enumerated()), id: \.offset) { _, sample in
                    Capsule()
                        .fill(isListening ? Color.mint.opacity(0.36 + Double(min(0.64, sample))) : Color.white.opacity(0.12))
                        .frame(width: 4, height: max(3, 30 * sample))
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(height: 32)
            .animation(.easeOut(duration: 0.12), value: waveform)
            VStack(spacing: 6) {
                ZStack {
                    Circle().fill(Color.mint.opacity(isListening ? 0.14 + Double(level) * 0.18 : 0.07))
                        .frame(width: 44, height: 44)
                    Circle().stroke(Color.mint.opacity(isListening ? 0.2 + Double(level) * 0.28 : 0.12), lineWidth: 1)
                        .frame(width: 44, height: 44)
                    Image(systemName: "mic.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isListening ? Color.mint : Color.secondary)
                }
                Text(isListening ? "Listening to your voice" : "Microphone ready")
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(.primary)
                Text(isListening ? "Speech is transcribed locally on this Mac" : "Start listening when you’re ready")
                    .font(.system(size: 9)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .padding(13)
        .background(
            LinearGradient(colors: [Color.mint.opacity(0.055), Color.white.opacity(0.018)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.075), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isListening ? "Live microphone level \(Int(level * 100)) percent" : "Microphone level idle")
        .accessibilityIdentifier("gridline.voiceTodo.meter")
    }
}

private struct WakePhraseConfidenceControl: View {
    let confidence: Int?
    let phrase: String?
    let threshold: Int
    let onAdjust: (Int) -> Void

    private var accepted: Bool { (confidence ?? 0) >= threshold }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: confidence == nil ? "ear" : (accepted ? "checkmark.circle.fill" : "exclamationmark.circle.fill"))
                    .foregroundStyle(confidence == nil ? Color.secondary : (accepted ? Color.mint : Color.orange))
                Text("WAKE PHRASE CONFIDENCE")
                    .font(.system(size: 8, weight: .bold, design: .monospaced)).tracking(0.6)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                if let confidence, let phrase {
                    Text("“\(phrase)” · ~\(confidence)% · \(accepted ? "ACCEPTED" : "IGNORED")")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(accepted ? Color.mint : Color.orange)
                        .lineLimit(1)
                } else {
                    Text("Waiting for “OK, problem” or “OK, next problem”")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.07))
                    if let confidence {
                        Capsule().fill(accepted ? Color.mint : Color.orange)
                            .frame(width: geometry.size.width * CGFloat(confidence) / 100)
                    }
                    Capsule().fill(Color.white.opacity(0.7)).frame(width: 2)
                        .offset(x: geometry.size.width * CGFloat(threshold) / 100)
                }
            }
            .frame(height: 4)
            HStack(spacing: 7) {
                Text("Accept either phrase at")
                    .font(.system(size: 9)).foregroundStyle(.secondary)
                Button { onAdjust(-5) } label: {
                    Image(systemName: "minus").font(.system(size: 8, weight: .bold))
                        .frame(width: 21, height: 21)
                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain).accessibilityLabel("Lower wake phrase confidence threshold")
                Text("\(threshold)%")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.mint).frame(minWidth: 34)
                    .accessibilityIdentifier("gridline.voiceTodo.confidenceThreshold")
                Button { onAdjust(5) } label: {
                    Image(systemName: "plus").font(.system(size: 8, weight: .bold))
                        .frame(width: 21, height: 21)
                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain).accessibilityLabel("Raise wake phrase confidence threshold")
                Spacer()
                Text("Lower = easier trigger · 20–90%")
                    .font(.system(size: 8)).foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(Color.white.opacity(0.06), lineWidth: 1))
        .help("Approximate Whisper segment score, not word-level probability. Both wake phrases use this threshold.")
        .accessibilityIdentifier("gridline.voiceTodo.confidence")
    }
}

private struct VoiceTodoControlButton: View {
    enum Kind: Equatable { case primary, quiet, danger }

    let title: String
    let icon: String
    let kind: Kind
    var isEnabled = true
    let action: () -> Void

    private var tint: Color {
        switch kind {
        case .primary: return Color.mint
        case .quiet: return Color.white
        case .danger: return Color(red: 1, green: 0.42, blue: 0.39)
        }
    }

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(kind == .primary ? Color.black.opacity(0.88) : tint)
                .padding(.horizontal, 13).frame(height: 35)
                .background(
                    kind == .primary ? Color.mint : tint.opacity(kind == .danger ? 0.11 : 0.055),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(tint.opacity(kind == .primary ? 0.0 : 0.19), lineWidth: 1))
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
    }
}
