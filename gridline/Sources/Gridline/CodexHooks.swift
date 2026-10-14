import Foundation
import SwiftUI

struct CodexHookInstallResult: Decodable {
    let ok: Bool
    let projectPath: String?
    let ponytailInstalled: Bool?
    let compactionLoggingEnabled: Bool?
    let ponytailFileExists: Bool?
    let message: String?
}

@MainActor
final class CodexHooksPanelModel: ObservableObject {
    @Published var isBusy = false
    @Published var status = ""
    @Published var ponytailInstalled = false
    @Published var compactionLoggingEnabled = false
    @Published var projectPath: String?

    func run(action: String, directory: String, completion: ((CodexHookInstallResult?) -> Void)? = nil) {
        guard !isBusy else { return }
        if action == "inspect" {
            ponytailInstalled = false
            compactionLoggingEnabled = false
            projectPath = nil
        }
        guard let resources = Bundle.main.resourceURL?.appendingPathComponent("hooks", isDirectory: true),
              FileManager.default.fileExists(atPath: resources.appendingPathComponent("install_project_hooks.py").path),
              let python = ["/opt/homebrew/bin/python3", "/usr/local/bin/python3", "/usr/bin/python3"]
                .first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            status = "Gridline's hook installer or Python 3 is unavailable."
            completion?(nil)
            return
        }

        isBusy = true
        status = action == "inspect" ? "Checking project hooks…" : "Updating project hooks…"
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let process = Process()
            let output = Pipe()
            let errors = Pipe()
            process.executableURL = URL(fileURLWithPath: python)
            process.arguments = [
                resources.appendingPathComponent("install_project_hooks.py").path,
                action,
                "--project-root", directory,
                "--resource-root", resources.path
            ]
            process.environment = ["PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin", "PYTHONDONTWRITEBYTECODE": "1"]
            process.standardOutput = output
            process.standardError = errors

            do {
                try process.run()
                let outputData = output.fileHandleForReading.readDataToEndOfFile()
                let errorData = errors.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                let result = try? JSONDecoder().decode(CodexHookInstallResult.self, from: outputData)
                let errorText = String(decoding: errorData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.isBusy = false
                    if let result {
                        self.ponytailInstalled = result.ponytailInstalled ?? false
                        self.compactionLoggingEnabled = result.compactionLoggingEnabled ?? false
                        self.projectPath = result.projectPath ?? directory
                        if result.ok {
                            let project = result.projectPath ?? directory
                            switch action {
                            case "inspect": self.status = "Project: \(project)"
                            case "install-ponytail": self.status = "Ponytail is installed in \(project). Existing Ponytail rules were kept."
                            case "enable-compactions": self.status = "Codex compaction logging is enabled for \(project)."
                            case "disable-compactions": self.status = "Codex compaction logging is disabled for \(project)."
                            default: self.status = "Codex hooks are installed in \(project)."
                            }
                        } else {
                            self.status = result.message ?? "Could not update project hooks."
                        }
                    } else {
                        self.status = errorText.isEmpty ? "Hook installer returned an invalid response." : errorText
                    }
                    completion?(result)
                }
            } catch {
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.isBusy = false
                    self.status = "Could not start the Gridline hook installer."
                    completion?(nil)
                }
            }
        }
    }
}

struct CodexHooksPanel: View {
    let groupID: UUID
    let groupName: String
    let directory: String
    let terminalSession: TerminalSession?
    let palette: GridlineTemplate.Palette

    @StateObject private var model = CodexHooksPanelModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(groupName.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text(directory)
                    .font(.system(size: 10, design: .monospaced))
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                    .accessibilityIdentifier("gridline.group.hooks.directory.\(groupID.uuidString)")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(palette.controlSurface, in: RoundedRectangle(cornerRadius: 6))

            MainTemplateDropdownActionRow(
                title: model.ponytailInstalled ? "Update Ponytail setup" : "Install Ponytail",
                subtitle: "Add Ponytail rules under this project's .codex folder",
                systemImage: "puzzlepiece.extension",
                tint: palette.accent,
                identifier: "gridline.group.hooks.ponytail.\(groupID.uuidString)",
                isDisabled: model.isBusy
            ) {
                run("install-ponytail")
            }

            MainTemplateDropdownActionRow(
                title: model.compactionLoggingEnabled ? "Disable compaction logging" : "Enable compaction logging",
                subtitle: "Record manual and automatic Codex compactions in Gridline Debug",
                systemImage: model.compactionLoggingEnabled ? "text.magnifyingglass" : "waveform.path.ecg",
                tint: model.compactionLoggingEnabled ? .orange : palette.accent,
                identifier: "gridline.group.hooks.compactions.\(groupID.uuidString)",
                isDisabled: model.isBusy
            ) {
                run(model.compactionLoggingEnabled ? "disable-compactions" : "enable-compactions")
            }

            Text("Review and trust project hooks in this Codex terminal with /hooks. A running session may need to restart to load changes.")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)

            if model.isBusy {
                ProgressView().controlSize(.small).frame(maxWidth: .infinity)
            }
            if !model.status.isEmpty {
                Text(model.status)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(model.status.hasPrefix("Could not") || model.status.contains("left unchanged") ? .orange : .secondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
                    .accessibilityIdentifier("gridline.group.hooks.status.\(groupID.uuidString)")
            }
        }
        .accessibilityIdentifier("gridline.group.hooks.panel.\(groupID.uuidString)")
        .onAppear { inspectProject() }
        .onChange(of: directory) { _ in inspectProject() }
    }

    private func inspectProject() {
        model.run(action: "inspect", directory: directory)
    }

    private func run(_ action: String) {
        model.run(action: action, directory: directory) { result in
            guard let result, result.ok else { return }
            DebugEvents.recordDiagnostic("provider.hooksConfigured", element: "gridline.group.hooks.\(groupID.uuidString)", details: [
                "language": "Swift",
                "provider": "codex",
                "action": action,
                "status": "completed",
                "terminalSession": terminalSession?.id.uuidString ?? "",
                "groupID": groupID.uuidString,
                "groupName": groupName,
                "pipeline": "MainTemplateWorkGroupCard.swift:projectHooks > CodexHooks.swift:CodexHooksPanelModel.run > hooks/install_project_hooks.py"
            ])
        }
    }
}

private struct PonytailVendorUpdateResult: Decodable {
    let ok: Bool
    let version: String?
    let commit: String?
    let changed: Bool?
    let message: String?
}

@MainActor
private final class PonytailVendorUpdateModel: ObservableObject {
    @Published var isBusy = false
    @Published var version = "Unknown"
    @Published var commit = ""
    @Published var status = ""

    func inspect() { run(action: "inspect") }
    func update() { run(action: "update") }

    private func run(action: String) {
        guard !isBusy else { return }
        guard let root = sourceRoot(),
              let resources = Bundle.main.resourceURL?.appendingPathComponent("hooks", isDirectory: true),
              FileManager.default.fileExists(atPath: resources.appendingPathComponent("update_ponytail_vendor.py").path),
              let python = ["/opt/homebrew/bin/python3", "/usr/local/bin/python3", "/usr/bin/python3"]
                .first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            status = "Ponytail vendor updates are available from the main Gridline source checkout."
            return
        }

        isBusy = true
        status = action == "inspect" ? "Checking Gridline's Ponytail source…" : "Pulling Ponytail updates…"
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let process = Process()
            let output = Pipe()
            let errors = Pipe()
            process.executableURL = URL(fileURLWithPath: python)
            process.arguments = [
                resources.appendingPathComponent("update_ponytail_vendor.py").path,
                action,
                "--repo-root", root.path
            ]
            process.environment = ["PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin", "PYTHONDONTWRITEBYTECODE": "1"]
            process.standardOutput = output
            process.standardError = errors

            do {
                try process.run()
                let outputData = output.fileHandleForReading.readDataToEndOfFile()
                let errorData = errors.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                let result = try? JSONDecoder().decode(PonytailVendorUpdateResult.self, from: outputData)
                let errorText = String(decoding: errorData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.isBusy = false
                    if let result, result.ok {
                        self.version = result.version ?? "unknown"
                        self.commit = result.commit ?? ""
                        if action == "inspect" {
                            self.status = "Vendored Ponytail \(self.version) · \(String(self.commit.prefix(12)))"
                        } else if result.changed == true {
                            self.status = "Ponytail source updated to \(self.version). New installs use it; existing project rules are preserved."
                            DebugEvents.recordDiagnostic("provider.ponytailVendorUpdated", element: "gridline.workspace.ponytailSource", details: [
                                "language": "Swift",
                                "provider": "codex",
                                "version": self.version,
                                "commit": self.commit,
                                "status": "completed",
                                "pipeline": "Workspace.swift:WorkspaceView.topBar > CodexHooks.swift:PonytailVendorUpdateModel.update > hooks/update_ponytail_vendor.py:git pull"
                            ])
                        } else {
                            self.status = result.message ?? "Ponytail source is already current."
                        }
                    } else {
                        self.status = result?.message ?? (errorText.isEmpty ? "Could not update Ponytail source." : errorText)
                    }
                }
            } catch {
                Task { @MainActor [weak self] in
                    self?.isBusy = false
                    self?.status = "Could not start the Ponytail source updater."
                }
            }
        }
    }

    private func sourceRoot() -> URL? {
        guard Bundle.main.bundleIdentifier == "local.gridline.terminal" else { return nil }
        let root = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("gridline/Package.swift").path),
              FileManager.default.fileExists(atPath: root.appendingPathComponent("hook_vendor/ponytail/VENDOR_VERSION").path) else { return nil }
        return root
    }
}

struct PonytailVendorUpdateView: View {
    let palette: GridlineTemplate.Palette

    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = PonytailVendorUpdateModel()
    @State private var showingConfirmation = false

    var body: some View {
        MainTemplateDropdownPanel(title: "PONYTAIL SOURCE", palette: palette, width: 410) {
            Text("This pulls Gridline's shared Ponytail vendor from the official upstream Git repository. New installs use the updated instructions. Existing project files stay unchanged; use a work group's Project hooks menu to refresh its hook helper.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)

            VStack(alignment: .leading, spacing: 3) {
                Text("VENDORED SOURCE · hook_vendor/ponytail")
                Text("GIT PULL CHECKOUT · hook_vendor/.ponytail-upstream")
            }
            .font(.system(size: 9, design: .monospaced))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .accessibilityIdentifier("gridline.workspace.ponytailSource.paths")

            MainTemplateDropdownActionRow(
                title: "Update shared Ponytail source…",
                subtitle: "Run git pull in Gridline's isolated upstream checkout",
                systemImage: "arrow.triangle.2.circlepath",
                tint: palette.accent,
                identifier: "gridline.workspace.ponytailSource.update",
                isDisabled: model.isBusy
            ) {
                showingConfirmation = true
            }

            if model.isBusy { ProgressView().controlSize(.small).frame(maxWidth: .infinity) }
            if !model.status.isEmpty {
                Text(model.status)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(model.status.hasPrefix("Could not") || model.status.contains("unexpected origin") ? .orange : .secondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
                    .accessibilityIdentifier("gridline.workspace.ponytailSource.status")
            }

            MainTemplateDropdownActionRow(
                title: "Done",
                systemImage: "checkmark",
                tint: palette.accent,
                identifier: "gridline.workspace.ponytailSource.done"
            ) { dismiss() }
        }
        .confirmationDialog(
            "Pull updates to Gridline's Ponytail vendor?",
            isPresented: $showingConfirmation,
            titleVisibility: .visible
        ) {
            Button("Git pull and update vendor") { model.update() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Gridline will pull from DietrichGebert/ponytail into its isolated vendor checkout, then refresh the shared source used for future workgroup installs.")
        }
        .onAppear { model.inspect() }
    }
}
