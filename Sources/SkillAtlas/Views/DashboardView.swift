import SwiftUI

struct DashboardView: View {
    @Environment(AppController.self) private var controller
    @State private var searchText = ""
    @State private var statusFilter: SyncStatus?
    @State private var showHealthOnly = false
    @State private var selectedSkillName: String?

    var filteredSkills: [SkillRecord] {
        var result = controller.skills
        if showHealthOnly { result = result.filter { !$0.healthWarnings.isEmpty } }
        if let filter = statusFilter { result = result.filter { $0.syncStatus == filter } }
        if !searchText.isEmpty {
            let lower = searchText.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(lower) ||
                ($0.description ?? "").lowercased().contains(lower)
            }
        }
        return result
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSkillName) {
                ForEach(filteredSkills) { skill in
                    SkillRowView(skill: skill)
                        .tag(skill.name)
                }
            }
            .listStyle(.inset)
            .overlay {
                if filteredSkills.isEmpty {
                    ContentUnavailableView(
                        "No Skills Found",
                        systemImage: "puzzlepiece.extension",
                        description: Text(controller.skills.isEmpty
                            ? "Run a scan to discover your skills"
                            : "Try adjusting your filters")
                    )
                }
            }
            .toolbar {
                ToolbarItemGroup {
                    TextField("Search...", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 160)

                    Picker("", selection: $statusFilter) {
                        Text("All").tag(nil as SyncStatus?)
                        ForEach(SyncStatus.allCases, id: \.self) { s in
                            Text(s.rawValue).tag(s as SyncStatus?)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 140)

                    Toggle("Issues", isOn: $showHealthOnly)
                        .toggleStyle(.checkbox)

                    Button(action: { Task { await controller.scan() } }) {
                        if controller.isScanning {
                            ProgressView().progressViewStyle(.circular).scaleEffect(0.5)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(controller.isScanning)
                    .help("Refresh")
                }
            }
        } detail: {
            if let name = selectedSkillName,
               let skill = controller.skills.first(where: { $0.name == name }) {
                SkillDetailView(skill: skill)
                    .environment(controller)
                    .id(skill.id)
            } else {
                VStack(spacing: 12) {
                    HStack(spacing: 16) {
                        StatBadge(value: controller.totalCount, label: "Total", color: .primary)
                        StatBadge(value: controller.consistentCount, label: "Consistent", color: .green)
                        StatBadge(value: controller.conflictedCount, label: "Conflicted", color: .red)
                        StatBadge(value: controller.onlyCodexCount, label: "Only Codex", color: .blue)
                        StatBadge(value: controller.onlyClaudeCount, label: "Only Claude", color: .orange)
                        StatBadge(value: controller.unhealthyCount, label: "Issues", color: .yellow)
                    }
                    Image(systemName: "puzzlepiece.extension")
                        .font(.system(size: 48)).foregroundStyle(.tertiary)
                    Text("Select a Skill").font(.title2).foregroundStyle(.secondary)
                    Text("Choose a skill from the sidebar to view details")
                        .font(.body).foregroundStyle(.tertiary)
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}

// MARK: - Stat Badge
struct StatBadge: View {
    let value: Int; let label: String; let color: Color
    var body: some View {
        HStack(spacing: 4) {
            Text("\(value)").font(.system(.body, design: .monospaced)).fontWeight(.bold).foregroundColor(color)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Skill Row
struct SkillRowView: View {
    let skill: SkillRecord
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: skill.syncStatus.iconName)
                .foregroundColor(statusColor).font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(skill.name).font(.body).fontWeight(.medium)
                if let desc = skill.description, !desc.isEmpty {
                    Text(desc).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            HStack(spacing: 4) {
                if skill.codexExists { SideBadge(label: "Cx", color: .blue) }
                if skill.claudeExists { SideBadge(label: "Cl", color: .orange) }
                if skill.isSymlinked { Image(systemName: "link").font(.caption2).foregroundStyle(.tertiary) }
            }
            if !skill.healthWarnings.isEmpty {
                Image(systemName: "exclamationmark.triangle.fill").font(.caption).foregroundColor(.yellow)
            }
            Text(skill.fileCountDisplay).font(.caption).foregroundStyle(.secondary).frame(width: 60, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }
    private var statusColor: Color {
        switch skill.syncStatus {
        case .consistent: return .green
        case .conflicted: return .red
        case .onlyCodex: return .blue
        case .onlyClaude: return .orange
        }
    }
}

struct SideBadge: View {
    let label: String; let color: Color
    var body: some View {
        Text(label).font(.system(.caption2, design: .monospaced)).fontWeight(.bold).foregroundColor(color)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(color.opacity(0.15)).clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
