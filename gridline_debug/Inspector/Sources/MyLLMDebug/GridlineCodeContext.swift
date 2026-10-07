import Foundation

enum GridlineCodeContext {
    static func sourcePath(for element: DebugElement) -> String {
        sourcePath(for: canonicalIdentifier(for: element))
    }

    static func expectedEvents(for element: DebugElement) -> String {
        expectedEvents(for: canonicalIdentifier(for: element))
    }

    static func actionSummary(for element: DebugElement) -> String {
        actionSummary(for: canonicalIdentifier(for: element), title: element.title)
    }

    static func sourcePath(for identifier: String) -> String {
        switch identifier {
        case "gridline.group.new":
            return "gridline/Sources/Gridline/Workspace.swift → WorkspaceView.body toolbar → WorkspaceStore.addGroup()"
        case "gridline.session.newCodex":
            return "gridline/Sources/Gridline/Workspace.swift → WorkspaceView.body toolbar → WorkspaceStore.addSession(kind: .codex)"
        case "gridline.layout.columns":
            return "gridline/Sources/Gridline/Workspace.swift → WorkspaceView.topBar → WorkspaceStore.setColumns(_:)"
        case "gridline.workspace.title":
            return "gridline/Sources/Gridline/Workspace.swift → WorkspaceView.body workspace header. The inline `cd` prompt in this row controls Gridline's default starting folder."
        case "gridline.workspace.directoryCommand", "gridline.workspace.defaultDirectory":
            return "gridline/Sources/Gridline/Workspace.swift → WorkspaceView.runDirectoryCommand() → WorkspaceStore.runDirectoryCommand(_:); supports cd, pwd, and ls, saves the default folder, and renders an organized directory listing."
        case "gridline.skillScript.menu", "gridline.skillScript.dropdown", "gridline.skillScript.audioToText",
             "gridline.skillScript.transcriptionModal", "gridline.skillScript.transcriptionLoading",
             "gridline.skillScript.transcript", "gridline.skillScript.transcriptStats",
             "gridline.skillScript.transcriptionOptions", "gridline.skillScript.speakerMode",
             "gridline.skillScript.pauseMode", "gridline.skillScript.startTranscription",
             "gridline.skillScript.copyTranscript", "gridline.skillScript.saveTranscript",
             "gridline.skillScript.closeTranscript", "gridline.skillScript.transcriptionError":
            return "gridline/Sources/Gridline/Workspace.swift → WorkspaceView custom skill_script dropdown → AudioTranscriptionOutputView; the Audio to text skill and helpers are in skill_script/audio_to_text/, with model assets in skill_script/resources/models/."
        case "gridline.skillScript.voiceTodo", "gridline.workspace.tab.voiceTodo", "gridline.workspace.tab.workspace",
             "gridline.voiceTodo.open", "gridline.voiceTodo.modal", "gridline.voiceTodo.start",
             "gridline.voiceTodo.endProblem", "gridline.voiceTodo.stop", "gridline.voiceTodo.input",
             "gridline.voiceTodo.status", "gridline.voiceTodo.meter", "gridline.voiceTodo.confidence",
             "gridline.voiceTodo.confidenceThreshold", "gridline.voiceTodo.copy", "gridline.voiceTodo.close", "gridline.voiceTodo.home":
            return "gridline/Sources/Gridline/Workspace.swift → WorkspaceView tabs and custom skill_script menu; live microphone capture and editable transcript modal are in gridline/Sources/Gridline/VoiceTodo.swift, with the persistent Whisper chunk worker in skill_script/voice_todo/voice_todo.py and the shared model in skill_script/resources/models/whisper-small-mlx/."
        case "gridline.workspace.groupSidebar.panel":
            return "gridline/Sources/Gridline/Workspace.swift → WorkspaceView.body → left work-group navigation overlay. It scrolls the main grid to a group; it does not close or restart terminals."
        case "gridline.workspace.groupSidebar":
            return "gridline/Sources/Gridline/Workspace.swift → WorkspaceView.body hamburger button; toggles the left navigation overlay without changing terminal sessions."
        case let id where id.hasPrefix("gridline.workspace.groupSidebar.item."):
            return "gridline/Sources/Gridline/Workspace.swift → WorkspaceView.body work-group sidebar item; scrolls to the matching group and briefly highlights its card."
        case let id where id.hasPrefix("gridline.group.toggle."):
            return "gridline/Sources/Gridline/Workspace.swift → WorkspaceView.groupCard(_:) → WorkspaceStore.toggle(_:)"
        case let id where id.hasPrefix("gridline.group.header."):
            return "gridline/Sources/Gridline/Workspace.swift → WorkspaceView.groupCard(_:) header HStack; this is the full gray work-group header region. Its child controls and work-group title have their own identifiers."
        case let id where id.hasPrefix("gridline.group.card."):
            return "gridline/Sources/Gridline/Workspace.swift → WorkspaceView.groupCard(_:) full work-group card container. Prefer a child identifier when the target is a specific button or terminal."
        case let id where id.hasPrefix("gridline.group.close."):
            return "gridline/Sources/Gridline/Workspace.swift → WorkspaceView.groupCard(_:) header close button → WorkspaceStore.closeGroup(_:); terminates the group's terminal sessions and removes the work-group cell."
        case let id where id.hasPrefix("gridline.group.name."):
            return "gridline/Sources/Gridline/Workspace.swift → WorkspaceView.groupCard(_:) → WorkspaceStore.renameGroup(_:to:) (double-click the name, then press Return)"
        case let id where id.hasPrefix("gridline.group.addCodex."):
            return "gridline/Sources/Gridline/Workspace.swift → WorkspaceView.groupCard(_:) menu → WorkspaceStore.addSession(to:kind:) with .codex"
        case let id where id.hasPrefix("gridline.group.addSession."):
            return "gridline/Sources/Gridline/Workspace.swift → WorkspaceView.groupCard(_:) menu container; starts a Codex terminal only when the work group has no terminal, and always offers project-folder selection."
        case let id where id.hasPrefix("gridline.group.folder."):
            return "gridline/Sources/Gridline/Workspace.swift → WorkspaceView.groupCard(_:) → WorkspaceStore.chooseDirectory(for:)"
        case let id where id.hasPrefix("gridline.group.startCodex."):
            return "gridline/Sources/Gridline/Workspace.swift → WorkspaceView.groupCard(_:) empty state → WorkspaceStore.addSession(to:kind:) with .codex"
        case let id where id.hasPrefix("gridline.session.label."):
            return "gridline/Sources/Gridline/Workspace.swift → WorkspaceView.sessionCard(_:) → TerminalSession.rename(_:) (double-click the label, then press Return)"
        case let id where id.hasPrefix("gridline.session.zoomIn.") || id.hasPrefix("gridline.session.zoomOut."):
            return "gridline/Sources/Gridline/Workspace.swift → WorkspaceView.sessionCard(_:) → TerminalSession.zoomIn()/zoomOut(); saves the selected terminal's font size in workspace.json"
        case let id where id.hasPrefix("gridline.session.fontSize."):
            return "gridline/Sources/Gridline/Workspace.swift → WorkspaceView.sessionCard(_:) font size display; per-session size is persisted with SavedSession"
        case let id where id.hasPrefix("gridline.session.resizeHeight."):
            return "gridline/Sources/Gridline/Workspace.swift → TerminalHeightResizeHandle → WorkspaceStore.resizeTerminal(_:to:save:); saves this terminal's height in workspace.json"
        case let id where id.hasPrefix("gridline.session.terminal."):
            return "gridline/Sources/Gridline/Workspace.swift → WorkspaceView.sessionCard(_:) → TerminalPane(session:) → TerminalSession.init(saved:directory:) starts SwiftTerm's LocalProcessTerminalView and launches /bin/zsh; Codex sessions send `codex` to that shell."
        case let id where id.hasPrefix("gridline.session.close."):
            return "gridline/Sources/Gridline/Workspace.swift → WorkspaceView.sessionCard(_:) → WorkspaceStore.close(_:)"
        default:
            return "Search gridline/Sources/Gridline/Workspace.swift and gridline/Sources/Gridline/DebugEvents.swift for the Accessibility identifier or visible title. The Accessibility hierarchy identifies the runtime control, not a guaranteed source line."
        }
    }

    static func expectedEvents(for identifier: String) -> String {
        switch identifier {
        case "gridline.group.new": return "workgroup.created; terminal.started"
        case "gridline.session.newCodex": return "session.created; terminal.started"
        case "gridline.layout.columns": return "layout.columnsChanged"
        case "gridline.workspace.directoryCommand", "gridline.workspace.defaultDirectory": return "workspace.defaultDirectoryChanged; workspace.directoryPrinted; workspace.directoryListed; workspace.directorySelected"
        case "gridline.workspace.groupSidebar": return "workspace.groupSidebarToggled"
        case let id where id.hasPrefix("gridline.workspace.groupSidebar.item."): return "workgroup.sidebarSelected"
        case "gridline.workspace.groupSidebar.panel": return "No direct action; selecting a child group row scrolls the main workspace."
        case "gridline.workspace.title": return "No direct action; use the directory command field."
        case "gridline.skillScript.menu": return "skillScript.menuToggled"
        case "gridline.skillScript.dropdown": return "Container only; choose a skill-script item."
        case "gridline.skillScript.audioToText": return "skillScript.selected"
        case "gridline.skillScript.voiceTodo": return "skillScript.selected; voiceTodo.listeningStarted; voiceTodo.listeningStopped; voiceTodo.problemEnded"
        case "gridline.workspace.tab.voiceTodo": return "voiceTodo.tabSelected"
        case "gridline.workspace.tab.workspace": return "workspace.tabSelected"
        case "gridline.voiceTodo.start": return "voiceTodo.listeningStarted"
        case "gridline.voiceTodo.stop": return "voiceTodo.listeningStopped"
        case "gridline.voiceTodo.endProblem": return "voiceTodo.problemEnded"
        case "gridline.voiceTodo.confidenceThreshold": return "voiceTodo.confidenceThresholdChanged"
        case "gridline.voiceTodo.confidence": return "No direct action; reports the latest approximate Whisper segment score and the shared acceptance threshold."
        case "gridline.voiceTodo.open": return "No direct event; opens the Voice todo modal."
        case "gridline.voiceTodo.input": return "No direct event; recognized speech updates the editable text box."
        case "gridline.voiceTodo.meter", "gridline.voiceTodo.status": return "No direct event; this view reflects live microphone input state and level."
        case "gridline.voiceTodo.copy": return "No direct event; copies the edited Voice todo text to the clipboard."
        case "gridline.voiceTodo.modal", "gridline.voiceTodo.home", "gridline.voiceTodo.close": return "No direct event; modal or page container."
        case "gridline.skillScript.speakerMode", "gridline.skillScript.pauseMode": return "No direct event; selection is passed to skill_script/audio_to_text/audio_to_text.py when started."
        case "gridline.skillScript.saveTranscript": return "skillScript.transcriptSaved"
        case let id where id.hasPrefix("gridline.group.toggle."): return "workgroup.toggled"
        case let id where id.hasPrefix("gridline.group.close."): return "workgroup.closed"
        case let id where id.hasPrefix("gridline.group.header."): return "No direct action; inspect child control events if one was clicked."
        case let id where id.hasPrefix("gridline.group.card."): return "Container only; use child control events to identify the action."
        case let id where id.hasPrefix("gridline.group.name."): return "workgroup.renamed"
        case let id where id.hasPrefix("gridline.group.addCodex."): return "session.created; terminal.started"
        case let id where id.hasPrefix("gridline.group.folder."): return "workgroup.folderChanged"
        case let id where id.hasPrefix("gridline.group.startCodex."): return "session.created; terminal.started"
        case let id where id.hasPrefix("gridline.session.label."): return "session.renamed"
        case let id where id.hasPrefix("gridline.session.zoomIn.") || id.hasPrefix("gridline.session.zoomOut."): return "terminal.zoomChanged"
        case let id where id.hasPrefix("gridline.session.fontSize."): return "No direct action; zoom buttons emit terminal.zoomChanged"
        case let id where id.hasPrefix("gridline.session.resizeHeight."): return "terminal.heightChanged"
        case let id where id.hasPrefix("gridline.session.terminal."): return "No semantic event is emitted for clicks or typing inside the terminal. Lifecycle events are terminal.started and terminal.exit; terminal text and keystrokes are not captured."
        case let id where id.hasPrefix("gridline.session.close."): return "session.closed; terminal.exit"
        default: return "See the recent Gridline behavior log below."
        }
    }

    private static func actionSummary(for identifier: String, title: String) -> String {
        switch identifier {
        case "gridline.group.new": return "Create a work group."
        case "gridline.session.newCodex": return "Create a new Codex terminal session."
        case "gridline.layout.columns": return "Change the workspace grid column count."
        case "gridline.workspace.title": return "Workspace header. Use the inline cd prompt in this row to set the default starting folder."
        case "gridline.skillScript.menu": return "Open Gridline's custom, workspace-styled list of text-extraction scripts."
        case "gridline.skillScript.dropdown": return "Custom skill-script dropdown panel."
        case "gridline.skillScript.audioToText": return "Open the file selector and run local Whisper transcription plus speaker diarization for copyable text."
        case "gridline.skillScript.transcriptionOptions": return "Choose speaker labels or a faster transcript with paragraph breaks after pauses."
        case "gridline.skillScript.speakerMode": return "Enable local speaker diarization and label turns Person 1, Person 2, and so on."
        case "gridline.skillScript.pauseMode": return "Skip speaker analysis and start a paragraph after pauses of about two seconds."
        case "gridline.skillScript.startTranscription": return "Run the selected local transcript mode for the chosen audio or video file."
        case "gridline.skillScript.transcriptionModal": return "Large custom in-app transcript dialog with loading, preview, copy, and save states."
        case "gridline.skillScript.transcriptionLoading": return "Custom animated local transcription progress view."
        case "gridline.skillScript.transcript": return "Scrollable, selectable transcript grouped into Person-labeled speaker turns."
        case "gridline.skillScript.transcriptStats": return "Transcript speaker-turn line and word counts."
        case "gridline.skillScript.copyTranscript": return "Copy the full transcript to the clipboard."
        case "gridline.skillScript.saveTranscript": return "Choose a destination and save the transcript as a plain-text file."
        case "gridline.skillScript.closeTranscript": return "Close the transcription dialog."
        case "gridline.skillScript.transcriptionError": return "Local transcription status or error message."
        case "gridline.workspace.directoryCommand": return "Run `cd`, `pwd`, or `ls`; press Tab after a partial `cd` to complete folder names. Choosing a match navigates there immediately. No other commands execute."
        case "gridline.workspace.defaultDirectory": return "Inline cd/pwd/ls prompt and current default folder display."
        case "gridline.workspace.groupSidebar": return "Show or hide the work-group navigation overlay. Terminal sessions keep running."
        case "gridline.workspace.groupSidebar.panel": return "Left-side work-group navigation overlay. It does not resize the grid or stop terminal sessions."
        case let id where id.hasPrefix("gridline.workspace.groupSidebar.item."): return "Scroll the workspace to this work group and highlight it briefly."
        case let id where id.hasPrefix("gridline.group.toggle."): return "Collapse or expand this work group."
        case let id where id.hasPrefix("gridline.group.close."): return "Close this work group and terminate all terminal sessions inside it."
        case let id where id.hasPrefix("gridline.group.header."): return "Work-group header area; identify a child control for its specific action."
        case let id where id.hasPrefix("gridline.group.card."): return "Work-group card container; identify a child control for its specific action."
        case let id where id.hasPrefix("gridline.group.name."): return "Rename this work group."
        case let id where id.hasPrefix("gridline.group.addCodex."): return "Add a Codex terminal to this work group."
        case let id where id.hasPrefix("gridline.group.addSession."): return "Open the menu for adding a terminal to this work group."
        case let id where id.hasPrefix("gridline.group.folder."): return "Choose or change this work group's project folder."
        case let id where id.hasPrefix("gridline.group.startCodex."): return "Start a Codex terminal in this work group."
        case let id where id.hasPrefix("gridline.session.label."): return "Rename this terminal session."
        case let id where id.hasPrefix("gridline.session.zoomIn."): return "Zoom in this terminal by one point. The size is saved for this terminal."
        case let id where id.hasPrefix("gridline.session.zoomOut."): return "Zoom out this terminal by one point. The size is saved for this terminal."
        case let id where id.hasPrefix("gridline.session.fontSize."): return "Current font size for this terminal, saved per session."
        case let id where id.hasPrefix("gridline.session.resizeHeight."): return "Drag this handle up or down to resize only this terminal pane. Height is saved per session."
        case let id where id.hasPrefix("gridline.session.terminal."): return "Interact with the \(title.isEmpty ? "terminal" : title). Gridline captures which terminal surface was clicked, not its input or output."
        case let id where id.hasPrefix("gridline.session.close."): return "Close this terminal session."
        default: return title.isEmpty ? "No action mapping yet; inspect the code path and Accessibility hierarchy." : "Selected control: \(title)"
        }
    }

    static func makeCopyText(
        element: DebugElement,
        wasClicked: Bool,
        click: InspectorEvent?,
        recentEvents: [String],
        projectRoot: URL
    ) -> String {
        let rawIdentifier = canonicalIdentifier(for: element)
        let canonicalID = inferredActionIdentifier(rawIdentifier, events: recentEvents, clickTime: click?.time)
        let hierarchyHint = element.hierarchy.last(where: { $0.contains("gridline.") }) ?? element.role
        let searchTerm = canonicalID.hasPrefix("gridline.group.close.")
            ? "closeGroup"
            : canonicalID != rawIdentifier
            ? canonicalID
            : element.identifier.isEmpty
            ? (element.title.isEmpty ? (canonicalID.isEmpty ? hierarchyHint : canonicalID) : element.title)
            : element.identifier
        let expected = expectedEvents(for: canonicalID)
        let quotedProjectRoot = "'" + projectRoot.path.replacingOccurrences(of: "'", with: "'\\''") + "'"
        let matchingEvents = relevantEvents(
            recentEvents,
            expected: eventNames(for: canonicalID),
            clickTime: click?.time,
            identifier: canonicalID
        )
        let behavior: String
        if !matchingEvents.isEmpty {
            behavior = matchingEvents.joined(separator: "\n")
        } else if expected.hasPrefix("No direct action") || expected.hasPrefix("Container only") {
            behavior = "No direct action event expected for this container."
        } else if expected.hasPrefix("No semantic event is emitted") {
            behavior = "This terminal click is identified, but terminal input and output are intentionally not logged. See the terminal lifecycle event names above."
        } else if click != nil {
            behavior = "No matching expected event was recorded within 2 minutes of this click."
        } else {
            behavior = "No matching events found in the recent app log."
        }
        return """
        # Gridline UI element context

        Selection: \(wasClicked ? "Clicked" : "Hovered or pinned")
        What this control does: \(actionSummary(for: canonicalID, title: element.title))
        App: \(element.app) (\(element.bundleID))
        Visible title: \(element.title.isEmpty ? "(none)" : element.title)
        Accessibility identifier: \(element.identifier.isEmpty ? "(none exposed)" : element.identifier)
        Accessibility role: \(element.role)\(element.subrole.isEmpty ? "" : " / \(element.subrole)")
        Accessibility frame: x=\(Int(element.axFrame.origin.x)), y=\(Int(element.axFrame.origin.y)), width=\(Int(element.axFrame.width)), height=\(Int(element.axFrame.height))
        Help: \(element.help.isEmpty ? "(none)" : element.help)
        Parent hierarchy: \(element.hierarchy.joined(separator: " → "))
        Process ID: \(element.pid)
        Click event: \(click.map { "\($0.kind) at \($0.time.formatted(date: .numeric, time: .standard)) — \($0.detail)" } ?? "(no click captured for this selection)")

        Likely code path:
        \(GridlineCodeContext.sourcePath(for: canonicalID))

        Expected semantic event names:
        \(GridlineCodeContext.expectedEvents(for: canonicalID))

        Exact search command:
        cd \(quotedProjectRoot) && rg -n -F '\(searchTerm)' gridline/Sources gridline_debug

        Matching Gridline behavior events near this click:
        \(behavior)
        """
    }

    private static func eventNames(for identifier: String) -> Set<String> {
        if identifier.hasPrefix("gridline.session.terminal.") { return ["terminal.started", "terminal.exit"] }
        return Set(expectedEvents(for: identifier).split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) })
    }

    private static func inferredActionIdentifier(_ identifier: String, events: [String], clickTime: Date?) -> String {
        guard identifier.hasPrefix("gridline.group.card."), let clickTime else { return identifier }
        let groupID = String(identifier.dropFirst("gridline.group.card.".count))
        let iso = ISO8601DateFormatter()
        let lower = clickTime.addingTimeInterval(-5)
        let upper = clickTime.addingTimeInterval(120)
        let wasClosed = events.contains { line in
            guard let data = line.data(using: .utf8),
                  let item = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  item["event"] as? String == "workgroup.closed",
                  let details = item["details"] as? [String: String],
                  details["groupID"] == groupID,
                  let rawTime = item["time"] as? String,
                  let time = iso.date(from: rawTime) else { return false }
            return (lower...upper).contains(time)
        }
        return wasClosed ? "gridline.group.close.\(groupID)" : identifier
    }

    private static func relevantEvents(_ lines: [String], expected expectedNames: Set<String>, clickTime: Date?, identifier: String) -> [String] {
        guard !expectedNames.isEmpty else { return [] }

        let terminalSessionID = identifier.hasPrefix("gridline.session.terminal.")
            ? String(identifier.dropFirst("gridline.session.terminal.".count))
            : nil
        let closedGroupID = identifier.hasPrefix("gridline.group.close.")
            ? String(identifier.dropFirst("gridline.group.close.".count))
            : nil
        let iso = ISO8601DateFormatter()
        let lowerBound = clickTime?.addingTimeInterval(-5)
        let upperBound = clickTime?.addingTimeInterval(120)
        return lines.compactMap { line -> (Date, String)? in
            guard let data = line.data(using: .utf8),
                  let item = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let name = item["event"] as? String,
                  expectedNames.contains(name),
                  let rawTime = item["time"] as? String,
                  let time = iso.date(from: rawTime) else { return nil }
            if let terminalSessionID {
                let details = item["details"] as? [String: String] ?? [:]
                guard details["session"] == terminalSessionID else { return nil }
            } else {
                if let closedGroupID {
                    let details = item["details"] as? [String: String] ?? [:]
                    guard details["groupID"] == closedGroupID else { return nil }
                }
                if let lowerBound, let upperBound, !(lowerBound...upperBound).contains(time) { return nil }
            }

            let details = (item["details"] as? [String: String] ?? [:])
                .sorted { $0.key < $1.key }
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: ", ")
            let timestamp = time.formatted(date: .numeric, time: .standard)
            let element = item["element"] as? String ?? ""
            return (time, "- \(timestamp) · \(name) · \(element)\(details.isEmpty ? "" : " · \(details)")")
        }
        .sorted { $0.0 < $1.0 }
        .suffix(5)
        .map(\.1)
    }

    private static func canonicalIdentifier(for element: DebugElement) -> String {
        if !element.identifier.isEmpty { return element.identifier }
        if let terminalID = element.hierarchy.reversed().first(where: { $0.contains("gridline.session.terminal.") }),
           let range = terminalID.range(of: "gridline.session.terminal.") {
            return String(terminalID[range.lowerBound...])
        }
        switch element.title.lowercased() {
        case "new work group": return "gridline.group.new"
        case "new codex": return "gridline.session.newCodex"
        case "terminal workspace": return "gridline.workspace.title"
        default: return ""
        }
    }
}
