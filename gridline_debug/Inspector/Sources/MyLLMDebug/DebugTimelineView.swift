import SwiftUI

struct DebugTimelineView: View {
    @ObservedObject var timeline: DebugTimelineStore
    @State private var expanded: Set<String> = []

    private let surface = Color(red: 0.10, green: 0.11, blue: 0.13)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("GRIDLINE LOGS")
                    .font(.system(size: 17, weight: .bold))
                Text("Live · \(timeline.filteredEntries.count) shown / \(timeline.entries.count) loaded")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                if !timeline.copyStatus.isEmpty {
                    Text(timeline.copyStatus).font(.system(size: 10)).foregroundStyle(.mint)
                }
                Button {
                    timeline.isFollowing.toggle()
                } label: {
                    Label(timeline.isFollowing ? "Following" : "Follow", systemImage: "arrow.down.to.line")
                }
                .buttonStyle(.bordered)
                .tint(timeline.isFollowing ? .mint : .gray)
                .help(timeline.isFollowing ? "Stop scrolling to new logs" : "Scroll to and follow new logs")
                .accessibilityIdentifier("gridline.debug.logs.follow")
            }

            HStack(spacing: 10) {
                Picker("Show", selection: $timeline.category) {
                    Text("Prompts + IN/OUT").tag("terminal")
                    Text("Prompts").tag("prompts")
                    Text("Codex hooks").tag("hooks")
                    Text("Usage updates").tag("usage")
                    Text("Python").tag("python")
                    Text("Swift").tag("swift")
                    Text("UI").tag("ui")
                    Text("Builds").tag("build")
                    Text("Failures").tag("failures")
                    Text("Everything").tag("all")
                }
                .frame(width: 190)
                .accessibilityIdentifier("gridline.debug.logs.category")
                Picker("Workgroup", selection: $timeline.workgroup) {
                    ForEach(timeline.workgroups, id: \.self) { Text($0).tag($0) }
                }
                .frame(width: 190)
                .accessibilityIdentifier("gridline.debug.logs.workgroup")
                TextField("Search prompt, event, token count, ID, or code path", text: $timeline.search)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("gridline.debug.logs.search")
                Button("Copy filtered") { timeline.copyFiltered() }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("gridline.debug.logs.copyFiltered")
                Button("Reset logs", role: .destructive) { timeline.resetLogs() }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("gridline.debug.logs.reset")
                    .help("Delete the local timeline, raw events, and saved build output.")
            }

            Divider()

            if timeline.filteredEntries.isEmpty {
                Spacer()
                Text(timeline.entries.isEmpty ? "Waiting for Gridline events…" : "No logs match these filters.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(timeline.filteredEntries) { entry in
                                row(entry).id(entry.id)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear { scrollToLatest(proxy) }
                    .onChange(of: timeline.filteredEntries.last?.id) { _ in scrollToLatest(proxy) }
                    .onChange(of: timeline.isFollowing) { _ in scrollToLatest(proxy) }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.055, green: 0.06, blue: 0.07))
        .accessibilityIdentifier("gridline.debug.logs")
    }

    private func scrollToLatest(_ proxy: ScrollViewProxy) {
        guard timeline.isFollowing, let latestID = timeline.filteredEntries.last?.id else { return }
        DispatchQueue.main.async {
            proxy.scrollTo(latestID, anchor: .bottom)
        }
    }

    private func row(_ entry: DebugTimelineEntry) -> some View {
        DisclosureGroup(isExpanded: Binding(
            get: { expanded.contains(entry.id) },
            set: { isOpen in
                if isOpen { expanded.insert(entry.id) } else { expanded.remove(entry.id) }
            }
        )) {
            VStack(alignment: .leading, spacing: 7) {
                if !entry.submissionID.isEmpty {
                    Text("Submission \(entry.submissionID)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                ForEach(entry.details.keys.sorted(), id: \.self) { key in
                    if let value = entry.details[key], key != "buildLog", key != "pipeline", key != "prompt" {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(key).foregroundStyle(.secondary).frame(width: 170, alignment: .leading)
                            Text(value).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .font(.system(size: 10, design: .monospaced))
                    }
                }
                if let pipeline = entry.details["pipeline"] {
                    Text("CODE PATH").font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary)
                    highlightedCodePath(pipeline)
                        .font(.system(size: 11, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let buildLog = entry.details["buildLog"], !buildLog.isEmpty {
                    Text("BUILD OUTPUT").font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary)
                    Text(buildLog)
                        .font(.system(size: 10, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.top, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 9) {
                    Text(entry.source.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(color(for: entry.source))
                        .frame(width: 52, alignment: .leading)
                    Text(entry.time)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text(entry.event)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
                Text(entry.summary)
                    .font(.system(size: 12, weight: entry.event == "prompt.submitted" ? .semibold : .regular,
                                  design: .monospaced))
                    .foregroundStyle(entry.isFailure ? Color.orange : Color.white.opacity(0.92))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(surface, in: RoundedRectangle(cornerRadius: 9))
    }

    private func color(for source: String) -> Color {
        switch source {
        case "Python": return .purple
        case "Swift": return .cyan
        case "Build": return .yellow
        default: return .mint
        }
    }

    private func highlightedCodePath(_ path: String) -> Text {
        let pieces = path.components(separatedBy: " > ")
        return pieces.enumerated().reduce(Text("")) { result, item in
            let separator = item.offset == 0 ? Text("") : Text("  ›  ").foregroundColor(.gray)
            let color: Color = item.element.contains(".py") ? .purple
                : item.element.contains(".swift") ? .cyan : .white
            return result + separator + Text(item.element).foregroundColor(color)
        }
    }
}
