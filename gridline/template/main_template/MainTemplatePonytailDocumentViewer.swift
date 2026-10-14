import SwiftUI

/// Edits the Ponytail guidance file belonging to one work group's project.
struct MainTemplatePonytailDocumentViewer: View {
    let groupID: UUID
    let groupName: String
    let projectPath: String

    @Environment(\.dismiss) private var dismiss
    @State private var contents = ""
    @State private var originalContents = ""
    @State private var status = "Loading ponytail.md…"
    @State private var isLoaded = false
    @State private var isSaving = false
    @State private var showingDiscardConfirmation = false

    private var documentURL: URL {
        URL(fileURLWithPath: projectPath, isDirectory: true)
            .appendingPathComponent(".codex", isDirectory: true)
            .appendingPathComponent("ponytail.md", isDirectory: false)
    }

    private var hasUnsavedChanges: Bool {
        isLoaded && contents != originalContents
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(groupName)
                        .font(.system(size: 14, weight: .semibold))
                    Text(".codex/ponytail.md")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel") { requestDismiss() }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("gridline.group.ponytailDocument.cancel.\(groupID.uuidString)")
                Button(isSaving ? "Saving…" : "Save") { save() }
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(!hasUnsavedChanges || isSaving)
                    .accessibilityIdentifier("gridline.group.ponytailDocument.save.\(groupID.uuidString)")
            }
            .padding(16)

            Divider()

            if isLoaded {
                TextEditor(text: $contents)
                    .font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .accessibilityLabel("Ponytail project instructions")
                    .accessibilityIdentifier("gridline.group.ponytailDocument.editor.\(groupID.uuidString)")
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                    Text("Couldn’t open ponytail.md")
                        .font(.system(size: 14, weight: .semibold))
                    Text(status)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Divider()

            HStack {
                Text(statusText)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
        }
        .frame(minWidth: 650, idealWidth: 820, minHeight: 440, idealHeight: 620)
        .accessibilityIdentifier("gridline.group.ponytailDocument.modal.\(groupID.uuidString)")
        .onAppear(perform: load)
        .confirmationDialog(
            "Discard unsaved changes?",
            isPresented: $showingDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button("Discard Changes", role: .destructive) { dismiss() }
            Button("Keep Editing", role: .cancel) {}
        } message: {
            Text("Your edits to .codex/ponytail.md have not been saved.")
        }
    }

    private var statusText: String {
        if isSaving { return "Saving changes…" }
        if hasUnsavedChanges { return "Unsaved changes" }
        return status
    }

    private func load() {
        do {
            let text = try String(contentsOf: documentURL, encoding: .utf8)
            contents = text
            originalContents = text
            status = "Loaded · edits are saved to this project’s .codex/ponytail.md"
            isLoaded = true
        } catch {
            status = "The project’s .codex/ponytail.md could not be read."
        }
    }

    private func save() {
        guard hasUnsavedChanges else { return }
        isSaving = true
        do {
            try contents.write(to: documentURL, atomically: true, encoding: .utf8)
            originalContents = contents
            status = "Saved · .codex/ponytail.md"
            isSaving = false
            DebugEvents.record("provider.ponytailDocumentSaved", element: "gridline.group.ponytailDocument.save.\(groupID.uuidString)", details: [
                "groupID": groupID.uuidString,
                "groupName": groupName,
                "file": ".codex/ponytail.md",
                "characterCount": String(contents.unicodeScalars.count)
            ])
        } catch {
            status = "Could not save .codex/ponytail.md. Check that the file is writable."
            isSaving = false
        }
    }

    private func requestDismiss() {
        if hasUnsavedChanges {
            showingDiscardConfirmation = true
        } else {
            dismiss()
        }
    }
}
