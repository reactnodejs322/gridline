import SwiftUI

struct InspectorView: View {
    @EnvironmentObject private var inspector: InspectorStore
    @StateObject private var timeline = DebugTimelineStore()
    @State private var savedReport = ""
    @State private var elementPanelHeight: CGFloat = 245
    @State private var dragStartHeight: CGFloat?

    private var element: DebugElement? { inspector.pinned ?? inspector.hovered }
    private let panel = Color(red: 0.10, green: 0.11, blue: 0.13)

    var body: some View {
        GeometryReader { geometry in
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
                    elementCard
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .frame(height: boundedElementPanelHeight(elementPanelHeight, availableHeight: geometry.size.height))
                splitter(availableHeight: geometry.size.height)
                DebugTimelineView(timeline: timeline)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color(red: 0.055, green: 0.06, blue: 0.07))
        }
        .foregroundStyle(Color.white.opacity(0.9))
        .onAppear { timeline.start(directory: inspector.debugDirectory) }
        .onDisappear { timeline.stop() }
        .alert("Context report saved", isPresented: Binding(get: { !savedReport.isEmpty }, set: { if !$0 { savedReport = "" } })) {
            Button("OK") { savedReport = "" }
        } message: { Text(savedReport) }
    }

    private func splitter(availableHeight: CGFloat) -> some View {
        Rectangle()
            .fill(Color.white.opacity(0.18))
            .frame(height: 10)
            .overlay {
                Capsule()
                    .fill(Color.white.opacity(0.72))
                    .frame(width: 46, height: 4)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        if dragStartHeight == nil { dragStartHeight = elementPanelHeight }
                        elementPanelHeight = boundedElementPanelHeight(
                            (dragStartHeight ?? elementPanelHeight) + value.translation.height,
                            availableHeight: availableHeight
                        )
                    }
                    .onEnded { _ in dragStartHeight = nil }
            )
            .accessibilityElement()
            .accessibilityLabel("Resize inspector and logs")
            .accessibilityHint("Drag up or down to resize the log panel")
            .accessibilityIdentifier("gridline.debug.logs.splitter")
    }

    private func boundedElementPanelHeight(_ requested: CGFloat, availableHeight: CGFloat) -> CGFloat {
        let minimum: CGFloat = 110
        let maximum = max(minimum, availableHeight - 290)
        return min(max(requested, minimum), maximum)
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
                Text("Search live logs or inspect a Gridline control")
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
                    Button("Save context report") { saveReport() }
                        .buttonStyle(.bordered)
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
            } else {
                Text(inspector.isInspecting ? "Click a control in Gridline to inspect it. Other apps are ignored." : "Start inspecting, then click the Gridline control you want to change.")
                    .font(.system(size: 11)).foregroundStyle(.secondary).padding(.vertical, 8)
            }
        }
        .padding(13).background(panel, in: RoundedRectangle(cornerRadius: 9))
    }

    private func sectionTitle(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon).font(.system(size: 9, weight: .bold)).tracking(0.7).foregroundStyle(.secondary)
    }

    private func saveReport() {
        do { savedReport = try inspector.saveReport().path }
        catch { savedReport = error.localizedDescription }
    }
}
