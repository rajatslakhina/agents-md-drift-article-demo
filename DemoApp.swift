import SwiftUI
import InstructionDrift

@main
struct DemoApp: App {
    var body: some Scene {
        WindowGroup {
            RootView(initial: LaunchScreen.fromArguments())
        }
    }
}

/// `-screen field|gate|fixed|rules` picks the first screen (used by the CI screenshots).
enum LaunchScreen: String {
    case field, gate, fixed, rules

    static func fromArguments() -> LaunchScreen {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-screen"), index + 1 < args.count else { return .field }
        return LaunchScreen(rawValue: args[index + 1]) ?? .field
    }
}

struct RootView: View {
    let initial: LaunchScreen
    @State private var tab: Int = 0
    @State private var fixed = false

    var body: some View {
        TabView(selection: $tab) {
            FieldStudyView()
                .tabItem { Label("Field audit", systemImage: "chart.bar.xaxis") }
                .tag(0)
            GateView(fixed: $fixed)
                .tabItem { Label("PR gate", systemImage: "checkmark.shield") }
                .tag(1)
            RulesView()
                .tabItem { Label("Rules", systemImage: "list.bullet.rectangle") }
                .tag(2)
        }
        .onAppear {
            switch initial {
            case .field: tab = 0
            case .gate: tab = 1
            case .fixed: tab = 1; fixed = true
            case .rules: tab = 2
            }
        }
    }
}

// MARK: - Field audit

struct FieldStudyView: View {
    private var percent: Int { Int((FieldStudy.changedShare * 100).rounded()) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(FieldStudy.changedSinceWritten) of \(FieldStudy.live)")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                        Text("paths named in AGENTS.md / CLAUDE.md files changed after the line naming them was last edited (\(percent)%).")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            StatPill(value: "\(FieldStudy.repos.count)", label: "repos")
                            StatPill(value: "\(FieldStudy.instructionFiles)", label: "files")
                            StatPill(value: "\(FieldStudy.fiveOrMore)", label: "5+ commits")
                            StatPill(value: "\(FieldStudy.confirmedFalse)", label: "now false")
                        }
                    }
                    .padding(.vertical, 6)
                }
                Section("Per repo: live paths, and how many changed since") {
                    ForEach(FieldStudy.repos.sorted { $0.live > $1.live }) { repo in
                        RepoRow(repo: repo)
                    }
                }
                Section {
                    Text("Public repos at the commits listed in docs/field-audit. Audited \(FieldStudy.auditedOn.description) with Tools/drift-audit.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Instruction drift")
        }
    }
}

struct StatPill: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.headline.monospacedDigit())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct RepoRow: View {
    let repo: FieldStudy.RepoResult

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(repo.name).font(.subheadline.weight(.medium)).lineLimit(1)
                Spacer()
                Text("\(repo.changedSinceWritten)/\(repo.live)").font(.caption.monospacedDigit())
            }
            GeometryReader { proxy in
                let share = repo.live == 0 ? 0 : CGFloat(repo.changedSinceWritten) / CGFloat(repo.live)
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.18))
                    Capsule().fill(Color.orange).frame(width: proxy.size.width * share)
                }
            }
            .frame(height: 6)
            if repo.confirmedGone > 0 {
                Text("\(repo.confirmedGone) path\(repo.confirmedGone == 1 ? "" : "s") named no longer exist\(repo.confirmedGone == 1 ? "s" : "")")
                    .font(.caption2).foregroundStyle(.red)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - PR gate

struct GateView: View {
    @Binding var fixed: Bool
    @State private var acknowledged: Set<String> = []

    private var gate: ReviewGate { fixed ? SampleWorkspace.fixedGate : SampleWorkspace.gate }
    private var checks: [RuleCheck] {
        gate.check(changedPaths: SampleWorkspace.changedPaths, acknowledged: acknowledged, today: SampleWorkspace.today)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VerdictBanner(verdict: gate.verdict(for: checks))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("PR #212: Move DocC catalog into PantryKit").font(.subheadline.weight(.semibold))
                        ForEach(SampleWorkspace.changedPaths, id: \.self) { path in
                            Text(path).font(.caption.monospaced()).foregroundStyle(.secondary)
                        }
                    }
                    Toggle("Owners fixed AGENTS.md", isOn: $fixed.animation())
                        .onChange(of: fixed) { _, _ in acknowledged = [] }
                }
                Section("Rules checked against the change") {
                    ForEach(checks, id: \.rule.id) { check in
                        RuleCheckRow(check: check, isAcknowledged: acknowledged.contains(check.rule.id)) {
                            acknowledged.insert(check.rule.id)
                        }
                    }
                }
            }
            .navigationTitle("AGENTS.md gate")
        }
    }
}

struct VerdictBanner: View {
    let verdict: GateVerdict

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.caption)
            }
            Spacer()
        }
        .foregroundStyle(.white)
        .padding(12)
        .background(color, in: RoundedRectangle(cornerRadius: 12))
        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
    }

    private var symbol: String {
        switch verdict {
        case .pass: return "checkmark.seal.fill"
        case .needsReview: return "eye.fill"
        case .blocked: return "xmark.octagon.fill"
        }
    }
    private var title: String {
        switch verdict {
        case .pass: return "Mergeable"
        case .needsReview: return "Needs rule owners"
        case .blocked: return "Blocked"
        }
    }
    private var detail: String {
        switch verdict {
        case .pass: return "Every rule this change touches was re-read."
        case .needsReview(let ids): return "Re-read: " + ids.joined(separator: ", ")
        case .blocked(let ids): return "False today: " + ids.joined(separator: ", ")
        }
    }
    private var color: Color {
        switch verdict {
        case .pass: return .green
        case .needsReview: return .orange
        case .blocked: return .red
        }
    }
}

struct RuleCheckRow: View {
    let check: RuleCheck
    let isAcknowledged: Bool
    let acknowledge: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(check.rule.id).font(.subheadline.monospaced().weight(.semibold))
                Spacer()
                SeverityChip(severity: check.worst, acknowledged: isAcknowledged)
            }
            ForEach(Array(check.issues.enumerated()), id: \.offset) { _, issue in
                Text(describe(issue)).font(.caption).foregroundStyle(.secondary)
            }
            if check.worst == .review {
                Button("Owner re-read it", action: acknowledge)
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 2)
    }

    private func describe(_ issue: RuleIssue) -> String {
        switch issue {
        case .deadAnchor(let path): return "Points at \(path), which no longer exists"
        case .expired(let day): return "review-by \(day.description) has passed"
        case .decisionSuperseded(let id, let replacement): return "\(id) was superseded by \(replacement)"
        case .anchoredCodeChanged(let paths): return "This PR changes " + paths.joined(separator: ", ")
        case .missingOwner: return "No owner"
        case .missingReviewBy: return "No review-by date"
        }
    }
}

struct SeverityChip: View {
    let severity: RuleIssue.Severity?
    let acknowledged: Bool

    var body: some View {
        Text(label)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.18), in: Capsule())
            .foregroundStyle(color)
    }

    private var label: String {
        if acknowledged { return "RE-READ" }
        switch severity {
        case .blocking?: return "FALSE"
        case .review?: return "REVIEW"
        case .warning?: return "UNOWNED"
        case nil: return "OK"
        }
    }
    private var color: Color {
        if acknowledged { return .green }
        switch severity {
        case .blocking?: return .red
        case .review?: return .orange
        case .warning?: return .gray
        case nil: return .green
        }
    }
}

// MARK: - Rules

struct RulesView: View {
    var body: some View {
        NavigationStack {
            List(SampleWorkspace.rules, id: \.id) { rule in
                VStack(alignment: .leading, spacing: 6) {
                    Text(rule.id).font(.headline.monospaced())
                    Text(rule.text.trimmingCharacters(in: .whitespaces)).font(.subheadline)
                    HStack(spacing: 8) {
                        RuleTag(text: rule.owner ?? "no owner")
                        RuleTag(text: rule.reviewBy.map { "review-by \($0.description)" } ?? "no review-by")
                        if let decision = rule.decision { RuleTag(text: decision) }
                    }
                    if !rule.anchors.isEmpty {
                        Text("Anchors: " + rule.anchors.joined(separator: ", "))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Pantry AGENTS.md")
        }
    }
}

struct RuleTag: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Color.accentColor.opacity(0.12), in: Capsule())
    }
}
