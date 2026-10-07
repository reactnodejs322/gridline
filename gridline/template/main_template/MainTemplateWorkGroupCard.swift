import AppKit
import SwiftUI

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
    @State private var showingActionsDropdown = false

    private var palette: GridlineTemplate.Palette { template.palette }
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
                } else {
                    Text("· \(session.label)")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .accessibilityLabel("Terminal label: \(session.label)")
                        .accessibilityIdentifier("gridline.session.label.\(session.id.uuidString)")
                        .onTapGesture(count: 2) { sessionDraft = session.label; editingSession = session.id }
                }
            }
            Spacer(minLength: 2)

            Button { showingActionsDropdown.toggle() } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Work group and terminal actions")
            .accessibilityIdentifier("gridline.group.addSession.\(group.id.uuidString)")
            .popover(isPresented: $showingActionsDropdown, arrowEdge: .bottom) {
                MainTemplateDropdownPanel(title: "WORK GROUP ACTIONS", palette: palette, width: 290) {
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
