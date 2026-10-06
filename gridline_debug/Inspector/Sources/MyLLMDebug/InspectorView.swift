import SwiftUI

struct InspectorView: View {
    @EnvironmentObject private var inspector: InspectorStore
    @State private var savedReport = ""

    private var element: DebugElement? { inspector.pinned ?? inspector.hovered }
    private let panel = Color(red: 0.10, green: 0.11, blue: 0.13)

    var body: some View {
        VStack(spacing: 0) {
            header
            HStack(spacing: 7) {
                Circle().fill(inspector.isInspecting ? Color.green : Color.orange).frame(width: 6, height: 6)
                Text(inspector.inspectionStatus)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 17).frame(minHeight: 38)
            .background(Color.black.opacity(0.18))
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    elementCard
                    appBehaviorCard
                }
                .padding(16)
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .background(Color(red: 0.055, green: 0.06, blue: 0.07))
        .foregroundStyle(Color.white.opacity(0.9))
        .alert("Context report saved", isPresented: Binding(get: { !savedReport.isEmpty }, set: { if !$0 { savedReport = "" } })) {
            Button("OK") { savedReport = "" }
        } message: { Text(savedReport) }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "scope").foregroundStyle(.mint)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 7) {
                    Text("Gridline Debug").font(.system(size: 14, weight: .semibold))
                    if let versionLabel = inspector.versionLabel {
                        Text(versionLabel.replacingOccurrences(of: "_", with: " "))
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.yellow.opacity(0.18), in: Capsule())
                            .foregroundStyle(.yellow)
                    }
                }
                Text("Inspect, annotate, and give an LLM a searchable report")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                Text("Target: \(inspector.targetDisplayName) · PID \(inspector.targetProcessIdentifier.map(String.init) ?? "not running")")
                    .font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary)
            }
            Spacer()
            Text(inspector.isTrusted ? "Accessibility allowed" : "Accessibility permission needed")
                .font(.system(size: 10)).foregroundStyle(inspector.isTrusted ? .green : .orange)
            if !inspector.isTrusted {
                Button("Set up access…") { inspector.requestPermission() }.buttonStyle(.borderedProminent)
            } else if inspector.isInspecting {
                Button("Stop inspecting") { inspector.stopInspecting() }.buttonStyle(.bordered)
            } else {
                Button("Start inspecting") { inspector.startInspecting() }.buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 17).frame(height: 58)
        .background(panel)
        .overlay(alignment: .bottom) { Divider().overlay(.white.opacity(0.08)) }
    }

    private var elementCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionTitle(inspector.selectionIsClick ? "LAST CLICKED GRIDLINE ELEMENT" : (inspector.pinned == nil ? "HOVERED GRIDLINE ELEMENT" : "PINNED GRIDLINE ELEMENT"), icon: inspector.selectionIsClick ? "hand.tap" : "cursorarrow")
                Spacer()
                if element != nil {
                    Button { inspector.copyElementContext() } label: {
                        Label("Copy LLM context", systemImage: "doc.on.doc")
                    }.buttonStyle(.borderedProminent).tint(.mint)
                }
            }
            if let element {
                LabeledContent("App", value: element.app)
                LabeledContent("Role", value: element.role + (element.subrole.isEmpty ? "" : " · " + element.subrole))
                LabeledContent("Title", value: element.title.isEmpty ? "(no title)" : element.title)
                LabeledContent("Identifier", value: element.identifier.isEmpty ? "(none)" : element.identifier)
                LabeledContent("Search terms", value: element.searchHint.isEmpty ? "(use role/title)" : element.searchHint)
                LabeledContent("Screen bounds", value: "x \(Int(element.axFrame.minX)), y \(Int(element.axFrame.minY)), \(Int(element.axFrame.width)) × \(Int(element.axFrame.height))")
                if let click = inspector.lastClick(for: element) {
                    LabeledContent("Clicked", value: "\(click.kind) · \(click.time.formatted(date: .numeric, time: .standard))")
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("LIKELY SWIFT CODE PATH").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
                    Text(GridlineCodeContext.sourcePath(for: element))
                        .font(.system(size: 10, design: .monospaced)).textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("EXPECTED GRIDLINE EVENT").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
                    Text(GridlineCodeContext.expectedEvents(for: element))
                        .font(.system(size: 10, design: .monospaced)).foregroundStyle(.mint)
                        .textSelection(.enabled)
                }
                Text(element.hierarchy.joined(separator: "  ›  "))
                    .font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary)
                    .textSelection(.enabled).lineLimit(3)
                if !inspector.copyStatus.isEmpty {
                    Text(inspector.copyStatus).font(.system(size: 9)).foregroundStyle(.mint)
                }
                Button(inspector.pinned == nil ? "Pin hovered element" : "Follow pointer again") {
                    if inspector.pinned == nil { inspector.pinHovered() } else { inspector.pinned = nil; inspector.selectionIsClick = false }
                }.buttonStyle(.plain).font(.system(size: 10)).foregroundStyle(.mint)
            } else {
                Text(inspector.isInspecting ? "Hover or click a control in Gridline. Other apps are ignored." : "Start inspecting, then hover or click the Gridline control you want to change.")
                    .font(.system(size: 11)).foregroundStyle(.secondary).padding(.vertical, 8)
            }
        }
        .padding(13).background(panel, in: RoundedRectangle(cornerRadius: 9))
    }

    private var appBehaviorCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                sectionTitle("RECENT GRIDLINE BEHAVIOR & STATE", icon: "list.bullet.rectangle")
                Spacer()
                Text("events.jsonl · live").font(.system(size: 9, design: .monospaced)).foregroundStyle(.tertiary)
            }
            Text("Actions such as creating groups, changing layout, and starting or closing sessions appear here.")
                .font(.system(size: 10)).foregroundStyle(.secondary)
            if inspector.appEvents.isEmpty {
                Text("No Gridline actions logged yet. Interact with Gridline while it is running.")
                    .font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary).padding(.vertical, 8)
            } else {
                ForEach(Array(inspector.appEvents.suffix(12).reversed().enumerated()), id: \.offset) { _, line in
                    Text(formatBehaviorEvent(line))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.82))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 5))
                }
            }
            HStack {
                Button("Save context report") { saveReport() }
                    .buttonStyle(.bordered).disabled(element == nil)
                Spacer()
                Text("Includes element, code path, clicks, and app events")
                    .font(.system(size: 9)).foregroundStyle(.tertiary)
            }
        }
        .padding(13).background(panel, in: RoundedRectangle(cornerRadius: 9))
    }

    private func formatBehaviorEvent(_ line: String) -> String {
        guard let data = line.data(using: .utf8),
              let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return line }
        let time = (event["time"] as? String).map { String($0.suffix(12)) } ?? ""
        let name = event["event"] as? String ?? "event"
        let elementName = event["element"] as? String ?? ""
        let details = (event["details"] as? [String: String] ?? [:])
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " · ")
        return [time, name, elementName, details].filter { !$0.isEmpty }.joined(separator: "  ·  ")
    }

    private func sectionTitle(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon).font(.system(size: 9, weight: .bold)).tracking(0.7).foregroundStyle(.secondary)
    }

    private func saveReport() {
        do { savedReport = try inspector.saveReport().path }
        catch { savedReport = error.localizedDescription }
    }
}
