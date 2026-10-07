import SwiftUI

/// Main-skin presentation for reusable provider usage and active-terminal data.
struct MainTemplateUsageStatusView: View {
    private static let comparisonBudgetUSD = 20.0

    let snapshot: ProviderUsageSnapshot
    @ObservedObject var codexUsage: CodexUsageStatus
    let palette: GridlineTemplate.Palette
    @State private var showingIntervalEditor = false

    private var weeklyCodexPercent: Int? {
        [codexUsage.primary, codexUsage.secondary]
            .compactMap { $0 }
            .first(where: { $0.windowDurationMins == 10080 })?
            .usedPercent
            .map { min(max($0, 0), 100) }
    }

    private var codexPlanAmount: Double? {
        guard let weeklyCodexPercent else { return nil }
        return Self.comparisonBudgetUSD * Double(weeklyCodexPercent) / 100
    }

    private var claudePercent: Int? {
        guard let amount = snapshot.claudeAPIEquivalentUSD else { return nil }
        return min(max(Int((amount / Self.comparisonBudgetUSD * 100).rounded()), 0), 100)
    }

    private func amount(_ value: Double?) -> String {
        guard let value else { return "$—" }
        return String(format: "$%.2f", value)
    }

    private var codexPlanName: String {
        codexUsage.plan?.uppercased() ?? "PLUS"
    }

    private var partialClaudeNote: String {
        snapshot.claudeUnpricedModels.isEmpty ? "" : " Some model rates were unavailable."
    }

    var body: some View {
        HStack(spacing: 0) {
            Button { showingIntervalEditor = true } label: {
                providerMeter(
                    title: "CHATGPT \(codexPlanName)",
                    percent: weeklyCodexPercent,
                    amount: amount(codexPlanAmount),
                    plan: "$20 PLAN"
                )
                .overlay(alignment: .trailing) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 7, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .offset(x: 7)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("ChatGPT Plus weekly usage and refresh settings")
            .accessibilityValue("\(weeklyCodexPercent.map { "\($0) percent used" } ?? "Usage unavailable"); automatic fetching \(codexUsage.automaticRefreshEnabled ? "on" : "disabled"); every \(intervalDescription(codexUsage.refreshIntervalMilliseconds))")
            .accessibilityIdentifier("gridline.workspace.tokenUsage")
            .help("Click to adjust ChatGPT usage refresh interval or disable automatic fetching.")
            .popover(isPresented: $showingIntervalEditor, arrowEdge: .bottom) {
                UsageRefreshSettingsPopover(codexUsage: codexUsage, palette: palette)
            }

            if snapshot.claudeActiveTerminals > 0 {
                Text("|")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 9)
                providerMeter(
                    title: "CLAUDE",
                    percent: claudePercent,
                    amount: amount(snapshot.claudeAPIEquivalentUSD),
                    plan: "WK"
                )
            }
        }
        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
        .lineLimit(1)
        .padding(.horizontal, 6)
        .help("ChatGPT is the reported weekly allowance; its dollar figure is the used share of the $20 plan price. Claude appears only while a Claude process is running in a Gridline terminal. Its bar compares a rolling seven-day API-equivalent estimate with a $20 reference. These are usage estimates, not subscription charges.\(snapshot.claudeActiveTerminals > 0 ? partialClaudeNote : "")")
    }

    private func intervalDescription(_ milliseconds: Int) -> String {
        if milliseconds % 60_000 == 0 { return "\(milliseconds / 60_000) minute(s)" }
        if milliseconds % 1_000 == 0 { return "\(milliseconds / 1_000) second(s)" }
        return "\(milliseconds) milliseconds"
    }

    private func providerMeter(title: String, percent: Int?, amount: String, plan: String) -> some View {
        HStack(spacing: 0) {
            Text(title)
                .foregroundStyle(.primary)
                .padding(.horizontal, 3)
            ProgressView(value: Double(percent ?? 0), total: 100)
                .progressViewStyle(.linear)
                .tint(.cyan)
                .frame(width: 60)
                .accessibilityHidden(true)
                .padding(.horizontal, 3)
            Text("\(percent.map { String($0) } ?? "—")% / 100%")
                .foregroundStyle(.secondary)
                .padding(.horizontal, 3)
            Text(amount)
                .foregroundStyle(.cyan)
                .padding(.horizontal, 3)
            Text(plan)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 3)
        }
    }
}

private struct UsageRefreshSettingsPopover: View {
    private enum Unit: String, CaseIterable, Identifiable {
        case milliseconds = "Milliseconds"
        case seconds = "Seconds"
        case minutes = "Minutes"
        var id: String { rawValue }

        var multiplier: Int {
            switch self {
            case .milliseconds: return 1
            case .seconds: return 1_000
            case .minutes: return 60_000
            }
        }
    }

    @ObservedObject var codexUsage: CodexUsageStatus
    let palette: GridlineTemplate.Palette
    @State private var value = "3"
    @State private var unit: Unit = .seconds

    private let presets: [(String, Int)] = [
        ("1 second", 1_000), ("2 seconds", 2_000), ("3 seconds", 3_000),
        ("5 seconds", 5_000), ("10 seconds", 10_000), ("30 seconds", 30_000),
        ("1 minute", 60_000), ("5 minutes", 300_000)
    ]

    private var intervalMilliseconds: Int? {
        guard let count = Int(value), count > 0 else { return nil }
        let product = count.multipliedReportingOverflow(by: unit.multiplier)
        guard !product.overflow,
              (CodexUsageStatus.minimumIntervalMilliseconds...CodexUsageStatus.maximumIntervalMilliseconds).contains(product.partialValue) else { return nil }
        return product.partialValue
    }

    var body: some View {
        MainTemplateDropdownPanel(title: "CHATGPT USAGE UPDATES", palette: palette) {
            Toggle(isOn: Binding(
                get: { !codexUsage.automaticRefreshEnabled },
                set: { codexUsage.setAutomaticRefreshEnabled(!$0) }
            )) {
                Text("Disable automatic fetching")
            }
            .accessibilityIdentifier("gridline.workspace.usageRefresh.auto")
            .help("When this is off, Gridline calls Codex every \(intervalDescription(codexUsage.refreshIntervalMilliseconds)). Turn it on to stop automatic usage fetches.")

            Picker("Update every", selection: Binding(
                get: { codexUsage.refreshIntervalMilliseconds },
                set: { codexUsage.setRefreshIntervalMilliseconds($0) }
            )) {
                ForEach(presets.indices, id: \.self) { index in
                    let item = presets[index]
                    Text(item.0).tag(item.1)
                }
                if !presets.contains(where: { $0.1 == codexUsage.refreshIntervalMilliseconds }) {
                    Text("Custom (\(intervalDescription(codexUsage.refreshIntervalMilliseconds)))")
                        .tag(codexUsage.refreshIntervalMilliseconds)
                }
            }
            .accessibilityIdentifier("gridline.workspace.usageRefresh.interval")
            .help("When “Disable automatic fetching” is off, Gridline calls Codex every this amount of time to refresh the usage bar.")

            Divider()
            Text("Custom interval")
                .font(.system(size: 10, weight: .semibold))
            HStack(spacing: 8) {
                TextField("3", text: $value)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 64)
                    .accessibilityLabel("Refresh interval amount")
                Picker("Unit", selection: $unit) {
                    ForEach(Unit.allCases) { unit in
                        Text(unit.rawValue).tag(unit)
                    }
                }
                .labelsHidden()
                .frame(width: 120)
            }
            HStack {
                if !codexUsage.automaticRefreshEnabled {
                    Button("Fetch once now") { codexUsage.refreshOnce() }
                }
                Spacer()
                Button("Apply custom") {
                    if let intervalMilliseconds {
                        codexUsage.setRefreshIntervalMilliseconds(intervalMilliseconds)
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(intervalMilliseconds == nil)
            }
        }
        .onAppear(perform: loadCurrentInterval)
        .accessibilityIdentifier("gridline.workspace.usageRefresh.intervalEditor")
    }

    private func intervalDescription(_ milliseconds: Int) -> String {
        if milliseconds % 60_000 == 0 { return "\(milliseconds / 60_000) min" }
        if milliseconds % 1_000 == 0 { return "\(milliseconds / 1_000) sec" }
        return "\(milliseconds) ms"
    }

    private func loadCurrentInterval() {
        let milliseconds = codexUsage.refreshIntervalMilliseconds
        if milliseconds % 60_000 == 0 {
            unit = .minutes
            value = String(milliseconds / 60_000)
        } else if milliseconds % 1_000 == 0 {
            unit = .seconds
            value = String(milliseconds / 1_000)
        } else {
            unit = .milliseconds
            value = String(milliseconds)
        }
    }
}
