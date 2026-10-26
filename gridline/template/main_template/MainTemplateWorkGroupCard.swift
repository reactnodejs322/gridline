import AppKit
import SwiftUI

private enum ProjectMarkdownDocument: String, CaseIterable, Hashable, Identifiable {
    case systemDesign
    case rustSkill
    case ponytail

    var id: String { rawValue }
    var path: String {
        switch self {
        case .systemDesign: "app_design/this_app_design_today.md"
        case .rustSkill: ".codex/RUST_SKILL.md"
        case .ponytail: ".codex/ponytail.md"
        }
    }
    var hookScript: String {
        switch self {
        case .systemDesign: "map_design_context.cjs"
        case .rustSkill: "rust_skill_context.cjs"
        case .ponytail: "ponytail_context.cjs"
        }
    }
    var hookPath: String { self == .ponytail ? ".codex/hooks/gridline/ponytail_context.cjs" : ".codex/hooks/\(hookScript)" }
    var identifierStem: String {
        switch self {
        case .systemDesign: "systemDesignDocument"
        case .rustSkill: "rustSkillDocument"
        case .ponytail: "ponytailDocument"
        }
    }
    var eventStem: String { identifierStem }
    var iconIdentifierStem: String {
        switch self {
        case .systemDesign: "systemDesignDocument"
        case .rustSkill: "rustSkillFile"
        case .ponytail: "ponytailInstalled"
        }
    }
    var editorLabel: String {
        switch self {
        case .systemDesign: "Map system design"
        case .rustSkill: "Rust skill instructions"
        case .ponytail: "Ponytail project instructions"
        }
    }
    var loadingDescription: String {
        switch self {
        case .systemDesign: "loaded at session start; map guidance is reminded on each prompt"
        case .rustSkill: "loaded when the Rust hook detects a .rs tool operation"
        case .ponytail: "loaded at session start and refreshed when the project map changes"
        }
    }
}

/// Main-skin presentation for a work group and its terminal label controls.
/// State changes and process actions stay in WorkspaceStore/TerminalSession.
struct MainTemplateWorkGroupCard: View {
    let group: SavedGroup
    let groupSessions: [TerminalSession]
    let template: GridlineTemplate
    @ObservedObject var workspace: WorkspaceStore
    @Binding var editingGroup: UUID?
    @Binding var groupDraft: String
    @Binding var editingSession: UUID?
    @Binding var sessionDraft: String
    let terminalUsage: [UUID: TerminalUsageSnapshot]
    let terminalUsageUpdatesEnabled: Bool
    @StateObject private var ponytailStatus = CodexHooksPanelModel()
    @StateObject private var aiWorkflowModel = CodexHooksPanelModel()
    @State private var visibleProjectDocuments: Set<ProjectMarkdownDocument> = []
    @State private var showingActionsDropdown = false
    @State private var showingProjectHooks = false
    @State private var showingAIWorkflow = false
    @State private var showingProjectDocument: ProjectMarkdownDocument?
    @State private var showingUsageSession: UUID?

    private var palette: GridlineTemplate.Palette { template.palette }
    private var projectDirectory: String {
        groupSessions.first?.currentDirectory ?? group.directory
    }
    private var projectMarkerDirectory: String {
        ponytailStatus.projectPath ?? projectDirectory
    }
    private var ponytailLogo: NSImage? {
        guard let url = Bundle.main.url(forResource: "ponytail-logo", withExtension: "png") else { return nil }
        return NSImage(contentsOf: url)
    }
    private var rustMascot: NSImage? {
        guard let url = Bundle.main.url(forResource: "rust-mascot", withExtension: "png") else { return nil }
        return NSImage(contentsOf: url)
    }
    private var tileColor: Color {
        let colors: [Color] = [
            Color(red: 0.95, green: 0.43, blue: 0.56),
            Color(red: 0.35, green: 0.78, blue: 0.91),
            Color(red: 0.45, green: 0.82, blue: 0.67),
            Color(red: 0.93, green: 0.72, blue: 0.36),
            Color(red: 0.68, green: 0.58, blue: 0.94),
            Color(red: 0.95, green: 0.55, blue: 0.36)
        ]
        let key = group.id.uuidString.replacingOccurrences(of: "-", with: "")
        let index = Int(key.prefix(2), radix: 16) ?? 0
        return colors[index % colors.count]
    }

    var body: some View {
        VStack(spacing: 0) {
            groupHeader

            if !group.isCollapsed {
                LazyVGrid(columns: [GridItem(.flexible())], spacing: 0) {
                    ForEach(groupSessions) { session in
                        MainTemplateTerminalCard(
                            session: session,
                            template: template,
                            workspace: workspace
                        )
                    }
                }

                if groupSessions.isEmpty {
                    Button("Start a Codex session") { workspace.addSession(to: group, kind: .codex) }
                        .font(.system(size: 11)).padding(.bottom, 12)
                        .accessibilityIdentifier("gridline.group.startCodex.\(group.id.uuidString)")
                }
            }
        }
        .background(palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(tileColor.opacity(0.82), lineWidth: 1.25))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("gridline.group.card.\(group.id.uuidString)")
        .sheet(item: $showingProjectDocument) { document in
            MainTemplateMarkdownDocumentViewer(
                groupID: group.id,
                groupName: group.name,
                projectPath: projectMarkerDirectory,
                documentPath: document.path,
                identifierStem: document.identifierStem,
                eventStem: document.eventStem,
                editorLabel: document.editorLabel
            )
        }
        .onChange(of: showingActionsDropdown) { isPresented in
            if !isPresented {
                showingProjectHooks = false
                inspectPonytail()
            }
        }
        .onAppear(perform: inspectPonytail)
        .onChange(of: projectDirectory) { _ in inspectPonytail() }
        .task(id: projectMarkerDirectory) {
            while !Task.isCancelled {
                let documents = Self.configuredProjectDocuments(at: projectMarkerDirectory)
                if visibleProjectDocuments != documents { visibleProjectDocuments = documents }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    private var groupHeader: some View {
        HStack(spacing: 6) {
            Circle().fill(tileColor).frame(width: 7, height: 7)

            if editingGroup == group.id {
                TextField("Work group name", text: $groupDraft, onCommit: {
                    workspace.renameGroup(group, to: groupDraft)
                    editingGroup = nil
                })
                .textFieldStyle(.plain).font(.system(size: 11, weight: .semibold, design: .monospaced))
                .accessibilityLabel("Work group name")
                .accessibilityIdentifier("gridline.group.name.\(group.id.uuidString)")
                .onExitCommand { editingGroup = nil }
            } else {
                Text(group.name).font(.system(size: 10, weight: .semibold, design: .monospaced)).lineLimit(1)
                    .accessibilityIdentifier("gridline.group.name.\(group.id.uuidString)")
                    .onTapGesture(count: 2) { groupDraft = group.name; editingGroup = group.id }
            }

            if let session = groupSessions.first {
                if terminalUsageUpdatesEnabled {
                    terminalUsageButton(for: session)
                }
                if editingSession == session.id {
                    TextField("Terminal label", text: $sessionDraft, onCommit: {
                        session.rename(sessionDraft)
                        editingSession = nil
                    })
                    .textFieldStyle(.plain)
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .accessibilityLabel("Terminal label for \(session.label)")
                    .accessibilityIdentifier("gridline.session.label.\(session.id.uuidString)")
                    .onExitCommand { editingSession = nil }
                }
            }
            Spacer(minLength: 2)

            ForEach(ProjectMarkdownDocument.allCases.filter { visibleProjectDocuments.contains($0) }) { document in
                projectDocumentButton(document)
            }

            Button {
                let isPresented = !showingActionsDropdown
                showingActionsDropdown = isPresented
                DebugEvents.record("workgroup.actionsMenuToggled", element: "gridline.group.addSession.\(group.id.uuidString)", details: [
                    "groupID": group.id.uuidString,
                    "groupName": group.name,
                    "expanded": String(isPresented)
                ])
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Work group and terminal actions")
            .accessibilityIdentifier("gridline.group.addSession.\(group.id.uuidString)")
            .sheet(isPresented: $showingAIWorkflow) {
                AgentWorkflowActionsModal(
                    groupID: group.id,
                    model: aiWorkflowModel,
                    directory: projectDirectory,
                    groupName: group.name,
                    palette: palette
                )
            }
            .popover(isPresented: $showingActionsDropdown, arrowEdge: .bottom) {
                MainTemplateDropdownPanel(
                    title: showingProjectHooks ? "PROJECT HOOKS" : "WORK GROUP ACTIONS",
                    palette: palette,
                    width: showingProjectHooks ? 390 : 290
                ) {
                    if showingProjectHooks {
                        CodexHooksPanel(
                            groupID: group.id,
                            groupName: group.name,
                            directory: projectDirectory,
                            terminalSession: groupSessions.first,
                            palette: palette
                        )

                        MainTemplateDropdownActionRow(
                            title: "Back to work group actions",
                            systemImage: "arrow.left",
                            tint: palette.accent,
                            identifier: "gridline.group.hooks.back.\(group.id.uuidString)"
                        ) {
                            showingProjectHooks = false
                        }
                    } else {
                        MainTemplateDropdownActionRow(
                            title: "AI workflow…",
                            subtitle: "Install the guide, then create or fix this project's workflow",
                            systemImage: "doc.text.magnifyingglass",
                            tint: palette.accent,
                            identifier: "gridline.group.aiWorkflow.\(group.id.uuidString)",
                            isDisabled: aiWorkflowModel.isBusy
                        ) {
                            showingActionsDropdown = false
                            DispatchQueue.main.async { showingAIWorkflow = true }
                            DebugEvents.recordDiagnostic("provider.aiWorkflowOpened", element: "gridline.group.aiWorkflow.\(group.id.uuidString)", details: [
                                "groupID": group.id.uuidString,
                                "groupName": group.name
                            ])
                        }

                        MainTemplateDropdownActionRow(
                            title: "Choose project folder…",
                            subtitle: "Set this work group’s folder",
                            systemImage: "folder",
                            tint: palette.accent,
                            identifier: "gridline.group.folder.\(group.id.uuidString)"
                        ) {
                            showingActionsDropdown = false
                            workspace.chooseDirectory(for: group)
                        }

                        MainTemplateDropdownActionRow(
                            title: "Project hooks…",
                            subtitle: "Ponytail and compaction logging for this project",
                            systemImage: "puzzlepiece.extension",
                            tint: palette.accent,
                            identifier: "gridline.group.hooks.\(group.id.uuidString)"
                        ) {
                            showingProjectHooks = true
                            DebugEvents.record("provider.hooksPanelOpened", element: "gridline.group.hooks.\(group.id.uuidString)", details: [
                                "groupID": group.id.uuidString,
                                "groupName": group.name
                            ])
                        }

                        if groupSessions.isEmpty {
                            MainTemplateDropdownActionRow(
                                title: "Start Codex session",
                                subtitle: "Open a terminal in this work group",
                                systemImage: "terminal",
                                tint: palette.accent,
                                identifier: "gridline.group.addCodex.\(group.id.uuidString)"
                            ) {
                                showingActionsDropdown = false
                                workspace.addSession(to: group, kind: .codex)
                            }
                        }

                        ForEach(groupSessions) { session in
                            VStack(alignment: .leading, spacing: 5) {
                                Text("TERMINAL · \(session.label.uppercased())")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.top, 4)

                                MainTemplateDropdownActionRow(
                                    title: "Code .",
                                    subtitle: "Open this terminal’s current folder in VS Code",
                                    systemImage: "chevron.left.forwardslash.chevron.right",
                                    tint: palette.accent,
                                    identifier: "gridline.session.openInVSCode.\(session.id.uuidString)"
                                ) {
                                    showingActionsDropdown = false
                                    session.openInVSCode()
                                }

                                MainTemplateDropdownActionRow(
                                    title: "Rename terminal…",
                                    systemImage: "pencil",
                                    tint: palette.accent,
                                    identifier: "gridline.session.rename.\(session.id.uuidString)"
                                ) {
                                    showingActionsDropdown = false
                                    sessionDraft = session.label
                                    editingSession = session.id
                                }

                                HStack(spacing: 6) {
                                    MainTemplateDropdownActionRow(
                                        title: "Zoom out",
                                        systemImage: "minus.magnifyingglass",
                                        tint: palette.accent,
                                        identifier: "gridline.session.zoomOut.\(session.id.uuidString)",
                                        isDisabled: session.fontSize <= TerminalSession.minimumFontSize
                                    ) {
                                        session.zoomOut()
                                    }
                                    MainTemplateDropdownActionRow(
                                        title: "Zoom in",
                                        systemImage: "plus.magnifyingglass",
                                        tint: palette.accent,
                                        identifier: "gridline.session.zoomIn.\(session.id.uuidString)",
                                        isDisabled: session.fontSize >= TerminalSession.maximumFontSize
                                    ) {
                                        session.zoomIn()
                                    }
                                }

                                Text("Font size: \(Int(session.fontSize)) pt")
                                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .accessibilityIdentifier("gridline.session.fontSize.\(session.id.uuidString)")

                                MainTemplateDropdownActionRow(
                                    title: "Close terminal",
                                    systemImage: "xmark.circle",
                                    tint: .red,
                                    identifier: "gridline.session.close.\(session.id.uuidString)"
                                ) {
                                    showingActionsDropdown = false
                                    workspace.close(session)
                                }
                            }
                        }

                        Divider()
                            .overlay(palette.border)
                        MainTemplateDropdownActionRow(
                            title: "Close work group",
                            systemImage: "xmark",
                            tint: .red,
                            identifier: "gridline.group.close.\(group.id.uuidString)"
                        ) {
                            showingActionsDropdown = false
                            workspace.closeGroup(group)
                        }
                    }
                }
            }

            Button {
                workspace.toggle(group)
            } label: {
                Image(systemName: group.isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(group.isCollapsed ? "Expand work group" : "Collapse work group")
            .accessibilityLabel(group.isCollapsed ? "Expand work group \(group.name)" : "Collapse work group \(group.name)")
            .accessibilityIdentifier("gridline.group.toggle.\(group.id.uuidString)")
        }
        .padding(.horizontal, 7).frame(height: 27)
        .background(tileColor.opacity(0.09))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Work group header: \(group.name)")
            .accessibilityIdentifier("gridline.group.header.\(group.id.uuidString)")
    }

    private func inspectPonytail() {
        ponytailStatus.run(action: "inspect", directory: projectDirectory)
    }

    private static func configuredProjectDocuments(at root: String) -> Set<ProjectMarkdownDocument> {
        let projectURL = URL(fileURLWithPath: root, isDirectory: true)
        let hooksURL = projectURL.appendingPathComponent(".codex/hooks.json", isDirectory: false)
        guard let data = try? Data(contentsOf: hooksURL),
              let hooks = try? JSONSerialization.jsonObject(with: data) else { return [] }

        func referencesHook(_ value: Any, named hookName: String) -> Bool {
            if let string = value as? String { return string.contains(hookName) }
            if let array = value as? [Any] { return array.contains { referencesHook($0, named: hookName) } }
            if let object = value as? [String: Any] { return object.values.contains { referencesHook($0, named: hookName) } }
            return false
        }

        return Set(ProjectMarkdownDocument.allCases.filter { document in
            FileManager.default.fileExists(atPath: projectURL.appendingPathComponent(document.path).path) &&
            FileManager.default.fileExists(atPath: projectURL.appendingPathComponent(document.hookPath).path) &&
            referencesHook(hooks, named: document.hookScript)
        })
    }

    @ViewBuilder
    private func projectDocumentButton(_ document: ProjectMarkdownDocument) -> some View {
        Button {
            showingProjectDocument = document
            DebugEvents.record("provider.\(document.eventStem)Opened", element: "gridline.group.\(document.iconIdentifierStem).\(group.id.uuidString)", details: [
                "groupID": group.id.uuidString,
                "groupName": group.name,
                "file": document.path
            ])
        } label: {
            Group {
                switch document {
                case .systemDesign:
                    Image(systemName: "map")
                        .font(.system(size: 14))
                case .rustSkill:
                    if let rustMascot {
                        Image(nsImage: rustMascot)
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(contentMode: .fit)
                    } else {
                        Image(systemName: "shippingbox")
                    }
                case .ponytail:
                    if let ponytailLogo {
                        Image(nsImage: ponytailLogo)
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(contentMode: .fit)
                    } else {
                        Image(systemName: "puzzlepiece.extension")
                    }
                }
            }
            .frame(width: 16, height: 16)
            .frame(width: 22, height: 22)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("\(document.path) · \(document.loadingDescription)")
        .accessibilityLabel("Open \(document.editorLabel): \(document.path)")
        .accessibilityIdentifier("gridline.group.\(document.iconIdentifierStem).\(group.id.uuidString)")
    }

    @ViewBuilder
    private func terminalUsageButton(for session: TerminalSession) -> some View {
        let snapshot = terminalUsage[session.id]
        Button { showingUsageSession = session.id } label: {
            Text(usageSummary(snapshot))
                .font(.system(size: 7.3, weight: .medium, design: .monospaced))
                .foregroundStyle(snapshot?.status == "available" ? palette.accent : Color.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(usageHelp(snapshot))
        .accessibilityLabel("Terminal usage for \(session.label)")
        .accessibilityValue(usageSummary(snapshot))
        .accessibilityHint(usageHelp(snapshot))
        .accessibilityIdentifier("gridline.session.usage.\(session.id.uuidString)")
        .popover(isPresented: Binding(
            get: { showingUsageSession == session.id },
            set: { if !$0 { showingUsageSession = nil } }
        ), arrowEdge: .bottom) {
            TerminalUsageDetailsPopover(
                snapshot: snapshot,
                updatesEnabled: terminalUsageUpdatesEnabled,
                palette: palette
            )
        }
    }

    private func usageSummary(_ snapshot: TerminalUsageSnapshot?) -> String {
        guard let snapshot, snapshot.status == "available" else {
            return "IN — · OUT — · TOTAL —"
        }
        let model = displayModel(snapshot.model) ?? snapshot.provider?.uppercased() ?? "AI"
        let cost: String
        if let amount = snapshot.amountUSD {
            cost = "~$\(amount < 0.01 ? String(format: "%.3f", amount) : String(format: "%.2f", amount))\(snapshot.hasPartialEstimate ? "+" : "")"
        } else {
            cost = "$—"
        }
        return "\(model) · SESSION IN \(compactCount(snapshot.inputTokens ?? 0)) · OUT \(compactCount(snapshot.outputTokens ?? 0)) · TOTAL \(compactCount(snapshot.totalTokens ?? 0)) · \(cost)"
    }

    private func usageHelp(_ snapshot: TerminalUsageSnapshot?) -> String {
        guard let snapshot else {
            return terminalUsageUpdatesEnabled
                ? "Waiting for this terminal's local provider usage metadata."
                : "Per-terminal usage updates are paused; no snapshot is available yet."
        }
        let pauseNote = terminalUsageUpdatesEnabled ? "" : " Live updates are paused; showing the last snapshot."
        if snapshot.diagnostic == "assigned_after_terminal_submission" {
            return "Matched to this terminal after its Enter submission and a provider usage update. Terminal focus does not assign usage.\(pauseNote)"
        }
        switch snapshot.status {
        case "no_provider": return "No Codex or Claude process is active in this terminal.\(pauseNote)"
        case "pending": return "The CLI has started; waiting for its first usage record.\(pauseNote)"
        case "ambiguous": return "More than one provider session could match this terminal, so usage is not assigned.\(pauseNote)"
        case "unavailable": return "No matching local provider usage record is available for this terminal.\(pauseNote)"
        default: return "IN, OUT, and TOTAL are cumulative for this provider session. Open for the latest Codex turn counts. The dollar value is an API-equivalent estimate.\(pauseNote)"
        }
    }

    private func compactCount(_ value: Int) -> String {
        let amount = Double(value)
        let divisor: Double
        let suffix: String
        switch value {
        case 1_000_000_000...: divisor = 1_000_000_000; suffix = "B"
        case 1_000_000...: divisor = 1_000_000; suffix = "M"
        case 1_000...: divisor = 1_000; suffix = "k"
        default: return String(value)
        }
        let formatted = String(format: "%.1f", amount / divisor)
        return "\(formatted.hasSuffix(".0") ? String(formatted.dropLast(2)) : formatted)\(suffix)"
    }

    private func displayModel(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        let parts = value.lowercased().split(separator: "-").map(String.init)
        if parts.first == "gpt", parts.count >= 3, let suffix = parts.last {
            return "GPT-\(parts[1..<(parts.count - 1)].joined(separator: ".")) \(suffix.capitalized)"
        }
        if parts.first == "claude", parts.count >= 3 {
            let family = parts[1].capitalized
            let version = parts.dropFirst(2).joined(separator: ".")
            return "Claude \(family) \(version)"
        }
        return value
    }
}

private struct TerminalUsageDetailsPopover: View {
    let snapshot: TerminalUsageSnapshot?
    let updatesEnabled: Bool
    let palette: GridlineTemplate.Palette

    var body: some View {
        MainTemplateDropdownPanel(title: "TERMINAL USAGE", palette: palette, width: 310) {
            if let snapshot, snapshot.status == "available" || snapshot.status == "pending" {
                Text(snapshot.models?.compactMap(displayModel).joined(separator: ", ") ?? "Provider model pending")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(palette.primaryText)
                Text("Session rows are cumulative. Latest turn is the newest Codex request. The dollar value is an API-equivalent estimate, not subscription billing.")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Divider().overlay(palette.border)
                usageRow("Session input", value: count(snapshot.inputTokens))
                usageRow("Session output", value: count(snapshot.outputTokens))
                usageRow("Session total", value: count(snapshot.totalTokens))
                if snapshot.provider == "codex" {
                    Divider().overlay(palette.border)
                    usageRow("Latest turn input", value: count(snapshot.latestTurnInputTokens))
                    usageRow("Latest turn output", value: count(snapshot.latestTurnOutputTokens))
                }
                usageRow("Cached input", value: count(snapshot.cachedInputTokens))
                usageRow("Cache writes", value: count(snapshot.cacheWriteInputTokens))
                usageRow("Reasoning output", value: count(snapshot.reasoningOutputTokens))
                Divider().overlay(palette.border)
                usageRow("API-equivalent estimate", value: amount(snapshot.amountUSD, partial: snapshot.hasPartialEstimate))
                if snapshot.hasPartialEstimate {
                    Text("Some model rates are unavailable: \((snapshot.unpricedModels ?? []).joined(separator: ", "))")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !updatesEnabled {
                    Text("Live updates are paused. The displayed values are the last collected snapshot.")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text(statusDescription)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var statusDescription: String {
        guard let snapshot else { return updatesEnabled ? "Waiting for local usage data." : "Usage tracking is paused." }
        switch snapshot.status {
        case "no_provider": return "No Codex or Claude process is active in this terminal."
        case "pending": return "The CLI is active. Its first usage record has not arrived yet."
        case "ambiguous": return "Gridline found more than one possible provider session and left the usage unassigned."
        case "monitor_error": return "The local usage reader reported an error. Select this label in Gridline Debug to inspect its diagnostic event."
        default: return "Gridline could not read a matching local usage record for this terminal."
        }
    }

    private func usageRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value).foregroundStyle(palette.primaryText)
        }
        .font(.system(size: 9, weight: .medium, design: .monospaced))
    }

    private func count(_ value: Int?) -> String {
        guard let value else { return "—" }
        return value.formatted(.number)
    }

    private func amount(_ value: Double?, partial: Bool) -> String {
        guard let value else { return "Unavailable" }
        let formatted = value < 0.01 ? String(format: "$%.4f", value) : String(format: "$%.2f", value)
        return "~\(formatted) API eq.\(partial ? "+" : "")"
    }

    private func displayModel(_ value: String) -> String? {
        let parts = value.lowercased().split(separator: "-").map(String.init)
        if parts.first == "gpt", parts.count >= 3, let suffix = parts.last {
            return "GPT-\(parts[1..<(parts.count - 1)].joined(separator: ".")) \(suffix.capitalized)"
        }
        if parts.first == "claude", parts.count >= 3 {
            return "Claude \(parts[1].capitalized) \(parts.dropFirst(2).joined(separator: "."))"
        }
        return value
    }
}

/// Main-skin terminal card. The visible label and its in-place editor share
/// one stable ID, so Gridline Debug can inspect the specific terminal in both states.
private struct MainTemplateTerminalCard: View {
    @ObservedObject var session: TerminalSession
    let template: GridlineTemplate
    @ObservedObject var workspace: WorkspaceStore

    var body: some View {
        VStack(spacing: 0) {
            TerminalPane(session: session)
            .frame(height: session.terminalHeight)
            .background(template.palette.terminalCanvas)
            TerminalHeightResizeHandle(sessionID: session.id, height: session.terminalHeight) { height, isFinal in
                workspace.resizeTerminal(session, to: height, save: isFinal)
            }
        }
    }
}
