import AppKit
import SwiftUI
import SwiftTerm

enum SessionKind: String, Codable { case codex, shell }

struct SavedGroup: Codable, Identifiable {
    var id: UUID
    var name: String
    var directory: String
    var isCollapsed: Bool
}

struct SavedSession: Codable, Identifiable {
    var id: UUID
    var groupID: UUID
    var kind: SessionKind
    var label: String
    var followsTerminalTitle: Bool
}

struct WorkspaceSnapshot: Codable {
    var groups: [SavedGroup]
    var sessions: [SavedSession]
    var defaultDirectory: String?
}

struct WorkspaceDirectoryEntry: Identifiable {
    let name: String
    let isDirectory: Bool
    let size: Int64
    var id: String { name }
}

struct WorkspaceCommandOutput: Identifiable {
    let id = UUID()
    let command: String
    let path: String
    let message: String?
    let entries: [WorkspaceDirectoryEntry]
    let error: Bool
    var completionCandidates: [String] = []
}

@MainActor
final class TerminalSession: NSObject, ObservableObject, Identifiable, LocalProcessTerminalViewDelegate {
    let id: UUID
    let groupID: UUID
    let kind: SessionKind
    let terminal: LocalProcessTerminalView
    @Published var label: String
    @Published var followsTerminalTitle: Bool
    @Published var isRunning = true
    var onChange: (() -> Void)?

    init(saved: SavedSession, directory: String) {
        id = saved.id
        groupID = saved.groupID
        kind = saved.kind
        label = saved.label
        followsTerminalTitle = saved.followsTerminalTitle
        terminal = LocalProcessTerminalView(frame: .zero)
        super.init()
        terminal.processDelegate = self
        terminal.startProcess(
            executable: "/bin/zsh",
            args: ["-l"],
            currentDirectory: directory
        )
        DebugEvents.record("terminal.started", element: kind == .codex ? "gridline.session.codex" : "gridline.session.shell", details: ["kind": kind.rawValue, "session": id.uuidString, "directory": directory])
        if kind == .codex {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                guard let self, self.isRunning else { return }
                self.terminal.send(txt: "codex\n")
            }
        }
    }

    func rename(_ value: String) {
        let name = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        label = name
        followsTerminalTitle = false
        DebugEvents.record("session.renamed", element: "gridline.session.label", details: ["session": id.uuidString, "label": name])
        onChange?()
    }

    nonisolated func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
        Task { @MainActor [weak self] in self?.receiveTerminalTitle(title) }
    }

    private func receiveTerminalTitle(_ title: String) {
        guard followsTerminalTitle else { return }
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        label = clean
        DebugEvents.record("terminal.title", element: "gridline.session.title", details: ["session": id.uuidString, "title": clean])
        onChange?()
    }

    nonisolated func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
    nonisolated func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
    nonisolated func processTerminated(source: TerminalView, exitCode: Int32?) {
        Task { @MainActor [weak self] in self?.receiveProcessExit(exitCode) }
    }

    private func receiveProcessExit(_ exitCode: Int32?) {
        isRunning = false
        DebugEvents.record("terminal.exit", element: "gridline.session.terminal", details: ["session": id.uuidString, "exitCode": exitCode.map(String.init) ?? "unknown"])
    }
}

@MainActor
final class WorkspaceStore: ObservableObject {
    @Published var groups: [SavedGroup] = []
    @Published private(set) var sessions: [TerminalSession] = []
    @Published var columns = 2
    @Published private(set) var defaultDirectory = NSHomeDirectory()
    private let saveURL: URL

    init() {
        var support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Gridline", isDirectory: true)
        if let version = Bundle.main.object(forInfoDictionaryKey: "GridlineVersionLabel") as? String,
           !version.isEmpty {
            support.appendPathComponent(version, isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        saveURL = support.appendingPathComponent("workspace.json")

        if let data = try? Data(contentsOf: saveURL),
           let saved = try? JSONDecoder().decode(WorkspaceSnapshot.self, from: data) {
            groups = saved.groups
            defaultDirectory = saved.defaultDirectory ?? saved.groups.first?.directory ?? NSHomeDirectory()
            sessions = saved.sessions.filter { item in
                saved.groups.contains(where: { $0.id == item.groupID })
            }.map { item in
                let directory = saved.groups.first(where: { $0.id == item.groupID })?.directory ?? NSHomeDirectory()
                return TerminalSession(saved: item, directory: directory)
            }
        } else {
            let group = SavedGroup(id: UUID(), name: "Working on webapp", directory: NSHomeDirectory(), isCollapsed: false)
            groups = [group]
            defaultDirectory = NSHomeDirectory()
            sessions = [makeSession(group: group, kind: .codex)]
        }
        wireChanges()
    }

    func groupSessions(_ group: SavedGroup) -> [TerminalSession] {
        sessions.filter { $0.groupID == group.id }
    }

    func addGroup() {
        let group = SavedGroup(id: UUID(), name: "New work", directory: defaultDirectory, isCollapsed: false)
        groups.append(group)
        sessions.append(makeSession(group: group, kind: .codex))
        DebugEvents.record("workgroup.created", element: "gridline.group.new", details: ["group": group.name, "id": group.id.uuidString])
        changed()
    }

    func changeDefaultDirectory(with command: String) -> String? {
        let input = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return nil }
        guard input == "cd" || input.hasPrefix("cd ") || input.hasPrefix("cd\t") else {
            return "Only `cd` is supported here."
        }

        var destination = input == "cd" ? "~" : String(input.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
        if destination.count >= 2,
           let first = destination.first,
           (first == "'" || first == "\""),
           destination.last == first {
            destination.removeFirst()
            destination.removeLast()
        }
        guard !destination.isEmpty else { return "Enter a folder after `cd`." }

        if destination == "~" {
            destination = NSHomeDirectory()
        } else if destination.hasPrefix("~/") {
            destination = NSHomeDirectory() + String(destination.dropFirst())
        }
        let targetURL = destination.hasPrefix("/")
            ? URL(fileURLWithPath: destination).standardizedFileURL
            : URL(fileURLWithPath: defaultDirectory, isDirectory: true)
                .appendingPathComponent(destination).standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: targetURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return "Folder not found: \(targetURL.path)"
        }

        let previous = defaultDirectory
        defaultDirectory = targetURL.path
        DebugEvents.record("workspace.defaultDirectoryChanged", element: "gridline.workspace.defaultDirectory", details: ["from": previous, "to": defaultDirectory])
        changed()
        return nil
    }

    func runDirectoryCommand(_ command: String) -> WorkspaceCommandOutput? {
        let input = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return nil }
        switch input {
        case "pwd":
            DebugEvents.record("workspace.directoryPrinted", element: "gridline.workspace.directoryCommand", details: ["path": defaultDirectory])
            return WorkspaceCommandOutput(command: input, path: defaultDirectory, message: defaultDirectory, entries: [], error: false)
        case "ls":
            do {
                let urls = try FileManager.default.contentsOfDirectory(
                    at: URL(fileURLWithPath: defaultDirectory, isDirectory: true),
                    includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
                    options: [.skipsHiddenFiles]
                )
                let entries = try urls.map { url -> WorkspaceDirectoryEntry in
                    let values = try url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
                    return WorkspaceDirectoryEntry(name: url.lastPathComponent, isDirectory: values.isDirectory ?? false, size: Int64(values.fileSize ?? 0))
                }.sorted {
                    if $0.isDirectory != $1.isDirectory { return $0.isDirectory }
                    return $0.name.localizedStandardCompare($1.name) == .orderedAscending
                }
                DebugEvents.record("workspace.directoryListed", element: "gridline.workspace.directoryCommand", details: ["path": defaultDirectory, "count": String(entries.count)])
                return WorkspaceCommandOutput(command: input, path: defaultDirectory, message: nil, entries: entries, error: false)
            } catch {
                return WorkspaceCommandOutput(command: input, path: defaultDirectory, message: error.localizedDescription, entries: [], error: true)
            }
        default:
            guard input == "cd" || input.hasPrefix("cd ") || input.hasPrefix("cd\t") else {
                return WorkspaceCommandOutput(command: input, path: defaultDirectory, message: "Supported commands: cd, pwd, ls.", entries: [], error: true)
            }
            if let message = changeDefaultDirectory(with: input) {
                return WorkspaceCommandOutput(command: input, path: defaultDirectory, message: message, entries: [], error: true)
            }
            return WorkspaceCommandOutput(command: input, path: defaultDirectory, message: defaultDirectory, entries: [], error: false)
        }
    }

    func directoryCompletions(for command: String) -> [String]? {
        let input = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard input == "cd" || input.hasPrefix("cd ") || input.hasPrefix("cd\t") else { return nil }
        var argument = input == "cd" ? "" : String(input.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
        if argument.first == "'" || argument.first == "\"" { argument.removeFirst() }
        if argument.last == "'" || argument.last == "\"" { argument.removeLast() }

        let slash = argument.lastIndex(of: "/")
        let parentExpression = slash.map { String(argument[..<$0]) } ?? ""
        let partialName = slash.map { String(argument[argument.index(after: $0)...]) } ?? argument
        let argumentPrefix = slash.map { String(argument[...$0]) } ?? ""
        var expandedParent = parentExpression
        if expandedParent == "~" {
            expandedParent = NSHomeDirectory()
        } else if expandedParent.hasPrefix("~/") {
            expandedParent = NSHomeDirectory() + String(expandedParent.dropFirst())
        }
        let parentURL: URL
        if expandedParent.isEmpty, slash != nil, !argumentPrefix.isEmpty {
            parentURL = URL(fileURLWithPath: "/", isDirectory: true)
        } else if expandedParent.isEmpty {
            parentURL = URL(fileURLWithPath: defaultDirectory, isDirectory: true)
        } else if expandedParent.hasPrefix("/") {
            parentURL = URL(fileURLWithPath: expandedParent, isDirectory: true).standardizedFileURL
        } else {
            parentURL = URL(fileURLWithPath: defaultDirectory, isDirectory: true)
                .appendingPathComponent(expandedParent).standardizedFileURL
        }
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: parentURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        return contents.compactMap { url -> String? in
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true,
                  url.lastPathComponent.lowercased().hasPrefix(partialName.lowercased()) else { return nil }
            return "cd \(argumentPrefix)\(url.lastPathComponent)/"
        }.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    func recordDirectorySelection(_ command: String) {
        DebugEvents.record("workspace.directorySelected", element: "gridline.workspace.directoryCommand", details: ["command": command, "path": defaultDirectory])
    }

    func addSession(to group: SavedGroup? = nil, kind: SessionKind) {
        let target: SavedGroup
        if let group {
            guard groupSessions(group).isEmpty else { return }
            target = group
        } else if let available = groups.first(where: { groupSessions($0).isEmpty }) {
            target = available
        } else {
            addGroup()
            return
        }
        guard let targetIndex = groups.firstIndex(where: { $0.id == target.id }) else { return }
        groups[targetIndex].directory = defaultDirectory
        let session = makeSession(group: groups[targetIndex], kind: kind)
        sessions.append(session)
        groups[targetIndex].isCollapsed = false
        DebugEvents.record("session.created", element: kind == .codex ? "gridline.session.newCodex" : "gridline.session.newShell", details: ["kind": kind.rawValue, "group": groups[targetIndex].name, "session": session.id.uuidString])
        changed()
    }

    func toggle(_ group: SavedGroup) {
        guard let index = groups.firstIndex(where: { $0.id == group.id }) else { return }
        groups[index].isCollapsed.toggle()
        DebugEvents.record("workgroup.toggled", element: "gridline.group.toggle", details: ["group": groups[index].name, "collapsed": String(groups[index].isCollapsed)])
        changed()
    }

    func renameGroup(_ group: SavedGroup, to name: String) {
        guard let index = groups.firstIndex(where: { $0.id == group.id }) else { return }
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleaned.isEmpty {
            let previous = groups[index].name
            groups[index].name = cleaned
            DebugEvents.record("workgroup.renamed", element: "gridline.group.name", details: ["from": previous, "to": cleaned])
            changed()
        }
    }

    func chooseDirectory(for group: SavedGroup) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Use Folder"
        guard panel.runModal() == .OK, let url = panel.url,
              let index = groups.firstIndex(where: { $0.id == group.id }) else { return }
        groups[index].directory = url.path
        DebugEvents.record("workgroup.folderChanged", element: "gridline.group.folder", details: ["group": groups[index].name, "path": url.path])
        changed()
    }

    func close(_ session: TerminalSession) {
        DebugEvents.record("session.closed", element: "gridline.session.close", details: ["label": session.label, "session": session.id.uuidString])
        session.terminal.terminate()
        sessions.removeAll { $0.id == session.id }
        changed()
    }

    func closeGroup(_ group: SavedGroup) {
        let groupSessions = groupSessions(group)
        let sessionIDs = groupSessions.map { $0.id.uuidString }
        groupSessions.forEach { $0.terminal.terminate() }
        sessions.removeAll { $0.groupID == group.id }
        groups.removeAll { $0.id == group.id }
        DebugEvents.record(
            "workgroup.closed",
            element: "gridline.group.close",
            details: ["group": group.name, "groupID": group.id.uuidString, "count": String(sessionIDs.count), "sessions": sessionIDs.joined(separator: ",")]
        )
        changed()
    }

    func setColumns(_ value: Int) {
        columns = value
        DebugEvents.record("layout.columnsChanged", element: "gridline.layout.columns", details: ["columns": String(value)])
    }

    private func makeSession(group: SavedGroup, kind: SessionKind) -> TerminalSession {
        let saved = SavedSession(
            id: UUID(), groupID: group.id, kind: kind,
            label: kind == .codex ? "Codex" : "Shell",
            followsTerminalTitle: true
        )
        return TerminalSession(saved: saved, directory: group.directory)
    }

    private func wireChanges() {
        sessions.forEach { $0.onChange = { [weak self] in self?.changed() } }
    }

    private func changed() {
        wireChanges()
        let savedSessions = sessions.map {
            SavedSession(id: $0.id, groupID: $0.groupID, kind: $0.kind, label: $0.label, followsTerminalTitle: $0.followsTerminalTitle)
        }
        let data = try? JSONEncoder().encode(WorkspaceSnapshot(groups: groups, sessions: savedSessions, defaultDirectory: defaultDirectory))
        if let data { try? data.write(to: saveURL, options: .atomic) }
        objectWillChange.send()
    }
}

struct TerminalPane: NSViewRepresentable {
    let session: TerminalSession
    func makeNSView(context: Context) -> LocalProcessTerminalView {
        applyAccessibilityContext(to: session.terminal)
        return session.terminal
    }
    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        applyAccessibilityContext(to: nsView)
    }

    @MainActor
    private func applyAccessibilityContext(to view: LocalProcessTerminalView) {
        let kind = session.kind == .codex ? "Codex" : "shell"
        view.setAccessibilityIdentifier("gridline.session.terminal.\(session.id.uuidString)")
        view.setAccessibilityLabel("\(session.label) \(kind) terminal")
        view.setAccessibilityHelp("Terminal session \(session.id.uuidString), work group \(session.groupID.uuidString). Terminal text and keystrokes are not recorded by Gridline debug events.")
    }
}

struct WorkspaceView: View {
    @EnvironmentObject private var workspace: WorkspaceStore
    @State private var editingGroup: UUID?
    @State private var groupDraft = ""
    @State private var editingSession: UUID?
    @State private var sessionDraft = ""
    @State private var directoryCommand = ""
    @State private var commandOutput: WorkspaceCommandOutput?
    @State private var directoryBarWidth: CGFloat = 0
    @State private var isGroupSidebarExpanded = false
    @State private var highlightedGroup: UUID?

    private let background = Color(red: 0.055, green: 0.06, blue: 0.07)

    var body: some View {
        VStack(spacing: 0) {
            topBar
            HStack(spacing: 9) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { isGroupSidebarExpanded.toggle() }
                    DebugEvents.record("workspace.groupSidebarToggled", element: "gridline.workspace.groupSidebar", details: ["expanded": String(!isGroupSidebarExpanded)])
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isGroupSidebarExpanded ? Color.mint : Color.secondary)
                        .frame(width: 28, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(isGroupSidebarExpanded ? "Hide work group list" : "Show work group list")
                .accessibilityLabel(isGroupSidebarExpanded ? "Hide work group list" : "Show work group list")
                .accessibilityIdentifier("gridline.workspace.groupSidebar")
                Image(systemName: "square.grid.2x2.fill").foregroundStyle(Color.mint)
                Text("Terminal workspace").font(.system(size: 12, weight: .medium))
                    .accessibilityIdentifier("gridline.workspace.title")
                Text("·").foregroundStyle(.secondary)
                Text("\(workspace.groups.count) work groups").foregroundStyle(.secondary)
                HStack(spacing: 7) {
                    Text("$").font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(Color.mint)
                    DirectoryCommandField(
                        text: $directoryCommand,
                        placeholder: workspace.defaultDirectory,
                        onSubmit: runDirectoryCommand,
                        onTab: completeDirectoryCommand
                    )
                        .frame(maxWidth: .infinity)
                        .help("Current folder: \(workspace.defaultDirectory). Enter cd <path>, pwd, or ls.")
                        .accessibilityLabel("Directory command. Current folder: \(workspace.defaultDirectory). Supported commands: cd, pwd, ls")
                        .accessibilityIdentifier("gridline.workspace.directoryCommand")
                }
                .padding(.horizontal, 9)
                .frame(height: 29)
                .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.1), lineWidth: 1))
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("gridline.workspace.defaultDirectory")
                .frame(maxWidth: .infinity)
                .popover(item: $commandOutput, attachmentAnchor: .rect(.bounds), arrowEdge: .top) { output in
                    WorkspaceCommandOutputView(output: output, width: directoryBarWidth) { completion in
                        selectDirectoryCompletion(completion)
                    }
                }
                .background {
                    GeometryReader { geometry in
                        Color.clear
                            .onAppear { directoryBarWidth = geometry.size.width }
                            .onChange(of: geometry.size.width) { newWidth in directoryBarWidth = newWidth }
                    }
                }
                Spacer(minLength: 8)
                Button { workspace.addGroup() } label: { Label("New work group", systemImage: "plus") }
                    .buttonStyle(.bordered).accessibilityIdentifier("gridline.group.new")
            }
            .font(.system(size: 12))
            .padding(.horizontal, 22).padding(.vertical, 13)
            Divider().overlay(Color.white.opacity(0.08))
            ScrollViewReader { proxy in
                ZStack(alignment: .leading) {
                    ScrollView {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14, alignment: .top), count: workspace.columns), alignment: .leading, spacing: 14) {
                            ForEach(workspace.groups) { group in
                                groupCard(group)
                                    .id(group.id)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.cyan.opacity(highlightedGroup == group.id ? 0.95 : 0), lineWidth: 2)
                                            .shadow(color: Color.cyan.opacity(highlightedGroup == group.id ? 0.55 : 0), radius: 8)
                                            .animation(.easeInOut(duration: 0.8), value: highlightedGroup)
                                            .allowsHitTesting(false)
                                    }
                            }
                        }
                        .padding(20)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if isGroupSidebarExpanded {
                        VStack(alignment: .leading, spacing: 9) {
                            Text("WORK GROUPS")
                                .font(.system(size: 10, weight: .semibold))
                                .tracking(0.8)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 11)
                                .padding(.top, 15)
                            ScrollView {
                                VStack(spacing: 4) {
                                    ForEach(workspace.groups) { group in
                                        Button {
                                            withAnimation(.easeInOut(duration: 0.35)) {
                                                proxy.scrollTo(group.id, anchor: .center)
                                                highlightedGroup = group.id
                                            }
                                            DebugEvents.record("workgroup.sidebarSelected", element: "gridline.workspace.groupSidebar.item", details: ["groupID": group.id.uuidString])
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                                                if highlightedGroup == group.id {
                                                    withAnimation(.easeOut(duration: 0.8)) { highlightedGroup = nil }
                                                }
                                            }
                                        } label: {
                                            HStack(spacing: 8) {
                                                Circle().fill(Color(red: 0.68, green: 0.86, blue: 0.48)).frame(width: 6, height: 6)
                                                Text(group.name).lineLimit(1)
                                                Spacer(minLength: 0)
                                                Text("\(workspace.groupSessions(group).count)")
                                                    .font(.system(size: 9, design: .monospaced))
                                                    .foregroundStyle(.secondary)
                                            }
                                            .font(.system(size: 11, weight: .medium))
                                            .padding(.horizontal, 9)
                                            .frame(height: 31)
                                            .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 6))
                                            .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                        .help("Scroll to \(group.name)")
                                        .accessibilityIdentifier("gridline.workspace.groupSidebar.item.\(group.id.uuidString)")
                                    }
                                }
                                .padding(.horizontal, 8)
                            }
                            Spacer(minLength: 0)
                        }
                        .frame(width: 205)
                        .frame(maxHeight: .infinity)
                        .background(Color(nsColor: .windowBackgroundColor).opacity(0.97))
                        .overlay(alignment: .trailing) { Divider().overlay(Color.white.opacity(0.08)) }
                        .shadow(color: .black.opacity(0.35), radius: 12, x: 5)
                        .zIndex(1)
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel("Work group navigation")
                        .accessibilityIdentifier("gridline.workspace.groupSidebar.panel")
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                }
            }
        }
        .background(background)
        .foregroundStyle(Color(red: 0.9, green: 0.91, blue: 0.92))
    }

    private func runDirectoryCommand() {
        guard !directoryCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let output = workspace.runDirectoryCommand(directoryCommand)
        let command = directoryCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        let isCD = command == "cd" || command.hasPrefix("cd ") || command.hasPrefix("cd\t")
        let isSuccessfulCD = isCD && output?.error == false
        commandOutput = isSuccessfulCD ? nil : output
        directoryCommand = ""
    }

    private func completeDirectoryCommand() {
        guard let matches = workspace.directoryCompletions(for: directoryCommand) else { return }
        if matches.count == 1 {
            directoryCommand = matches[0]
            commandOutput = nil
        } else {
            commandOutput = WorkspaceCommandOutput(
                command: "cd",
                path: workspace.defaultDirectory,
                message: matches.isEmpty ? "No matching folders." : "Choose a folder to navigate there:",
                entries: [],
                error: matches.isEmpty,
                completionCandidates: matches
            )
        }
    }

    private func selectDirectoryCompletion(_ command: String) {
        if workspace.changeDefaultDirectory(with: command) == nil {
            workspace.recordDirectorySelection(command)
            directoryCommand = ""
            commandOutput = nil
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Group {
                if let logoURL = Bundle.main.url(forResource: "Gridline2x", withExtension: "png"),
                   let logo = NSImage(contentsOf: logoURL) {
                    Image(nsImage: logo)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: "command")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.mint)
                }
            }
            .frame(width: 30, height: 30)
            .accessibilityLabel("Gridline logo")
            .accessibilityIdentifier("gridline.workspace.brandLogo")
            Text("GRIDLINE").font(.system(size: 11, weight: .bold, design: .rounded)).tracking(1.2)
            Rectangle().fill(Color.white.opacity(0.12)).frame(width: 1, height: 19).padding(.horizontal, 3)
            Text("myllm").font(.system(size: 12, weight: .medium))
            Text("/  local Codex workspace").font(.system(size: 11)).foregroundStyle(.secondary)
            Spacer()
            Circle().fill(Color.green).frame(width: 7, height: 7)
            Text("Local machine").font(.system(size: 10)).foregroundStyle(.secondary)
            Menu {
                Button("Two columns") { workspace.setColumns(2) }
                Button("Three columns") { workspace.setColumns(3) }
                Button("One column") { workspace.setColumns(1) }
            } label: { Image(systemName: "rectangle.split.3x1").frame(width: 30, height: 25) }
                .menuStyle(.borderlessButton).help("Change grid layout")
                .accessibilityIdentifier("gridline.layout.columns")
        }
        .padding(.horizontal, 18).frame(height: 48)
        .background(Color(red: 0.075, green: 0.08, blue: 0.09))
        .overlay(alignment: .bottom) { Divider().overlay(Color.white.opacity(0.08)) }
    }

    private func groupCard(_ group: SavedGroup) -> some View {
        let groupSessions = workspace.groupSessions(group)
        return VStack(spacing: 0) {
            HStack(spacing: 9) {
                Button { workspace.toggle(group) } label: {
                    Image(systemName: group.isCollapsed ? "chevron.right" : "chevron.down")
                        .font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary).frame(width: 15, height: 24)
                }.buttonStyle(.plain).accessibilityIdentifier("gridline.group.toggle.\(group.id.uuidString)")
                Circle().fill(Color(red: 0.68, green: 0.86, blue: 0.48)).frame(width: 7, height: 7)
                if editingGroup == group.id {
                    TextField("Work group name", text: $groupDraft, onCommit: {
                        workspace.renameGroup(group, to: groupDraft); editingGroup = nil
                    }).textFieldStyle(.plain).font(.system(size: 13, weight: .semibold))
                        .onExitCommand { editingGroup = nil }
                } else {
                    Text(group.name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                        .accessibilityIdentifier("gridline.group.name.\(group.id.uuidString)")
                        .onTapGesture(count: 2) { groupDraft = group.name; editingGroup = group.id }
                }
                Text("\(groupSessions.count)").font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                Spacer(minLength: 4)
                Button { groupDraft = group.name; editingGroup = group.id } label: { Image(systemName: "pencil").font(.system(size: 10)) }
                    .buttonStyle(.plain).foregroundStyle(.secondary).help("Rename work group")
                Menu {
                    if groupSessions.isEmpty {
                        Button("Start Codex session") { workspace.addSession(to: group, kind: .codex) }
                            .accessibilityIdentifier("gridline.group.addCodex.\(group.id.uuidString)")
                    }
                    Divider()
                    Button("Choose project folder…") { workspace.chooseDirectory(for: group) }
                } label: { Image(systemName: "plus").font(.system(size: 11, weight: .semibold)).frame(width: 22, height: 22) }
                    .menuStyle(.borderlessButton).help(groupSessions.isEmpty ? "Start the group's Codex terminal or choose its folder" : "Choose this group's project folder")
                    .accessibilityIdentifier("gridline.group.addSession.\(group.id.uuidString)")
                Button { workspace.closeGroup(group) } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Close this work group and all its terminals")
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Close work group \(group.name) and its terminals")
                    .accessibilityIdentifier("gridline.group.close.\(group.id.uuidString)")
            }
            .padding(.horizontal, 12).frame(height: 43)
            .background(Color.white.opacity(0.035))
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Work group header: \(group.name)")
            .accessibilityIdentifier("gridline.group.header.\(group.id.uuidString)")

            if !group.isCollapsed {
                HStack(spacing: 5) {
                    Image(systemName: "folder").font(.system(size: 9))
                    Text(group.directory == NSHomeDirectory() ? "~" : group.directory)
                        .lineLimit(1).truncationMode(.middle)
                    Spacer()
                    Button("Change") { workspace.chooseDirectory(for: group) }
                        .buttonStyle(.plain).foregroundStyle(Color(red: 0.65, green: 0.78, blue: 0.56))
                        .accessibilityIdentifier("gridline.group.folder.\(group.id.uuidString)")
                }
                .font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary)
                .padding(.horizontal, 12).padding(.vertical, 8)

                LazyVGrid(columns: [GridItem(.flexible())], spacing: 8) {
                    ForEach(groupSessions) { session in sessionCard(session) }
                }
                .padding(.horizontal, 9).padding(.bottom, 9)
                if groupSessions.isEmpty {
                    Button("Start a Codex session") { workspace.addSession(to: group, kind: .codex) }
                        .font(.system(size: 11)).padding(.bottom, 12)
                        .accessibilityIdentifier("gridline.group.startCodex.\(group.id.uuidString)")
                }
            }
        }
        .background(Color(red: 0.10, green: 0.105, blue: 0.115))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.10), lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("gridline.group.card.\(group.id.uuidString)")
    }

    private func sessionCard(_ session: TerminalSession) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 7) {
                Circle().fill(session.isRunning ? Color.green : Color.gray).frame(width: 6, height: 6)
                if editingSession == session.id {
                    TextField("Session label", text: $sessionDraft, onCommit: {
                        session.rename(sessionDraft); editingSession = nil
                    }).textFieldStyle(.plain).font(.system(size: 10, weight: .medium))
                        .onExitCommand { editingSession = nil }
                } else {
                    Text(session.label).font(.system(size: 10, weight: .medium)).lineLimit(1)
                        .accessibilityIdentifier("gridline.session.label.\(session.id.uuidString)")
                        .onTapGesture(count: 2) { sessionDraft = session.label; editingSession = session.id }
                }
                Text(session.kind == .codex ? "CODEX" : "SHELL")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 3))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 2)
                Button { sessionDraft = session.label; editingSession = session.id } label: { Image(systemName: "pencil").font(.system(size: 9)) }
                    .buttonStyle(.plain).foregroundStyle(.secondary).help("Rename session")
                Button { workspace.close(session) } label: { Image(systemName: "xmark").font(.system(size: 9, weight: .medium)) }
                    .buttonStyle(.plain).foregroundStyle(.secondary).help("Close session")
                    .accessibilityIdentifier("gridline.session.close.\(session.id.uuidString)")
            }
            .padding(.horizontal, 9).frame(height: 31)
            .background(Color(red: 0.12, green: 0.125, blue: 0.135))
            TerminalPane(session: session)
                .frame(height: 220)
                .background(Color(red: 0.035, green: 0.04, blue: 0.045))
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.09), lineWidth: 1))
    }
}

private struct DirectoryCommandField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let onSubmit: () -> Void
    let onTab: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField(frame: .zero)
        field.delegate = context.coordinator
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        field.placeholderAttributedString = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: NSColor.secondaryLabelColor]
        )
        field.setAccessibilityIdentifier("gridline.workspace.directoryCommand")
        field.setAccessibilityLabel("Directory command prompt")
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.parent = self
        if field.stringValue != text { field.stringValue = text }
        field.placeholderAttributedString = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: NSColor.secondaryLabelColor]
        )
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: DirectoryCommandField
        init(_ parent: DirectoryCommandField) { self.parent = parent }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertTab(_:)) {
                parent.onTab()
                return true
            }
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit()
                return true
            }
            return false
        }
    }
}

private struct WorkspaceCommandOutputView: View {
    let output: WorkspaceCommandOutput
    let width: CGFloat
    let onChooseCompletion: (String) -> Void
    @State private var didCopyPath = false

    private var directories: [WorkspaceDirectoryEntry] { output.entries.filter(\.isDirectory) }
    private var files: [WorkspaceDirectoryEntry] { output.entries.filter { !$0.isDirectory } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(terminalPrompt)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(output.error ? Color.orange : Color.mint)
                    .lineLimit(1)
                Spacer()
                Button(didCopyPath ? "Copied" : "Copy path") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(output.path, forType: .string)
                    didCopyPath = true
                }
                .buttonStyle(.borderless)
                .font(.system(size: 10))
            }

            Text(output.path)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let message = output.message {
                Text(message)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(output.error ? Color.orange : Color.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !output.completionCandidates.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 3) {
                    Text("MATCHING FOLDERS")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                    ForEach(output.completionCandidates, id: \.self) { command in
                        Button { onChooseCompletion(command) } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "folder.fill").foregroundStyle(Color.mint).frame(width: 15)
                                Text(command)
                                    .font(.system(size: 10, design: .monospaced))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                Text("cd here").font(.system(size: 9)).foregroundStyle(.tertiary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Change directory to \(command)")
                    }
                }
            } else if output.command == "ls" {
                Divider()
                if output.entries.isEmpty {
                    Text("This folder is empty.")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            if !directories.isEmpty {
                                entrySection("FOLDERS", entries: directories)
                            }
                            if !files.isEmpty {
                                entrySection("FILES", entries: files)
                            }
                        }
                        .padding(.vertical, 3)
                    }
                    .frame(maxHeight: 280)
                }
            }
        }
        .padding(14)
        .frame(width: max(width, 1), alignment: .leading)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var terminalPrompt: String {
        let host = ProcessInfo.processInfo.hostName.components(separatedBy: ".").first ?? "Mac"
        let name = URL(fileURLWithPath: output.path).lastPathComponent
        return "\(NSUserName())@\(host) \(name) % \(output.command)"
    }

    @ViewBuilder
    private func entrySection(_ title: String, entries: [WorkspaceDirectoryEntry]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
            ForEach(entries) { entry in
                if entry.isDirectory {
                    Button {
                        let target = URL(fileURLWithPath: output.path, isDirectory: true)
                            .appendingPathComponent(entry.name).path
                        onChooseCompletion("cd \(target)")
                    } label: {
                        entryRow(entry)
                    }
                    .buttonStyle(.plain)
                    .help("Change directory to \(entry.name)")
                    .accessibilityLabel("Open folder \(entry.name)")
                } else {
                    entryRow(entry)
                }
            }
        }
    }

    private func entryRow(_ entry: WorkspaceDirectoryEntry) -> some View {
        HStack(spacing: 8) {
            Image(systemName: entry.isDirectory ? "folder.fill" : "doc.text")
                .font(.system(size: 11))
                .foregroundStyle(entry.isDirectory ? Color.mint : Color.secondary)
                .frame(width: 15)
            Text(entry.name)
                .font(.system(size: 10, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 8)
            Text(entry.isDirectory ? "Folder" : ByteCountFormatter.string(fromByteCount: entry.size, countStyle: .file))
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}
