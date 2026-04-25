import SwiftUI

struct DashboardView: View {
    @Environment(AppController.self) private var controller
    @State private var searchText = ""
    @State private var statusFilter: SyncStatus?
    @State private var showHealthOnly = false

    var filteredSkills: [SkillRecord] {
        var result = controller.skills

        if showHealthOnly {
            result = result.filter { !$0.healthWarnings.isEmpty }
        }

        if let filter = statusFilter {
            result = result.filter { $0.syncStatus == filter }
        }

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
        VStack(spacing: 0) {
            // Summary bar
            summaryBar
                .padding(.horizontal)
                .padding(.vertical, 8)

            Divider()

            // Filters
            filterBar
                .padding(.horizontal)
                .padding(.vertical, 6)

            Divider()

            // Skill list
            skillList
        }
        .toolbar {
            ToolbarItem {
                Button(action: { Task { await controller.scan() } }) {
                    if controller.isScanning {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(controller.isScanning)
                .help("Refresh scan")
            }
        }
    }

    // MARK: - Summary Bar
    private var summaryBar: some View {
        HStack(spacing: 16) {
            StatBadge(value: controller.totalCount, label: "Total", color: .primary)
            StatBadge(value: controller.consistentCount, label: "Consistent", color: .green)
            StatBadge(value: controller.conflictedCount, label: "Conflicted", color: .red)
            StatBadge(value: controller.onlyCodexCount, label: "Only Codex", color: .blue)
            StatBadge(value: controller.onlyClaudeCount, label: "Only Claude", color: .orange)
            StatBadge(value: controller.unhealthyCount, label: "Issues", color: .yellow)

            Spacer()

            if controller.isScanning {
                HStack(spacing: 6) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.6)
                    Text("Scanning...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Filter Bar
    private var filterBar: some View {
        HStack {
            TextField("Search skills...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 250)

            Picker("Status", selection: $statusFilter) {
                Text("All").tag(nil as SyncStatus?)
                ForEach(SyncStatus.allCases, id: \.self) { status in
                    Text(status.rawValue).tag(status as SyncStatus?)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 400)

            Toggle("Issues only", isOn: $showHealthOnly)
                .toggleStyle(.checkbox)
                .font(.caption)
        }
    }

    // MARK: - Skill List
    private var skillList: some View {
        List(filteredSkills) { skill in
            SkillRowView(skill: skill)
                .contentShape(Rectangle())
                .onTapGesture {
                    controller.selectedSkill = skill
                }
                .sheet(item: Bindable(controller).selectedSkill) { skill in
                    SkillDetailView(skill: skill)
                        .environment(controller)
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
    }
}

// MARK: - Stat Badge
struct StatBadge: View {
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Text("\(value)")
                .font(.system(.body, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Skill Row
struct SkillRowView: View {
    let skill: SkillRecord

    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            Image(systemName: skill.syncStatus.iconName)
                .foregroundColor(statusColor)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(skill.name)
                    .font(.body)
                    .fontWeight(.medium)

                if let desc = skill.description, !desc.isEmpty {
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Sides
            HStack(spacing: 4) {
                if skill.codexExists {
                    SideBadge(label: "Cx", color: .blue)
                }
                if skill.claudeExists {
                    SideBadge(label: "Cl", color: .orange)
                }
                if skill.isSymlinked {
                    Image(systemName: "link")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            // Health
            if !skill.healthWarnings.isEmpty {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(.yellow)
            }

            // File count
            Text(skill.fileCountDisplay)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .trailing)

            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
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

// MARK: - Side Badge
struct SideBadge: View {
    let label: String
    let color: Color

    var body: some View {
        Text(label)
            .font(.system(.caption2, design: .monospaced))
            .fontWeight(.bold)
            .foregroundColor(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
