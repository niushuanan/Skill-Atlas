import SwiftUI

// MARK: - 侧边栏
struct DashboardSidebar: View {
    @Environment(AppController.self) private var controller
    @Binding var selectedFilter: FilterCategory
    @Binding var selectedSkillName: String?
    @State private var searchText = ""

    enum FilterCategory: String, CaseIterable {
        case all = "全部"
        case consistent = "一致"
        case conflicted = "冲突"
        case onlyCodex = "仅 Codex"
        case onlyClaude = "仅 Claude"
        case issues = "异常"

        var icon: String {
            switch self {
            case .all: return "tray.full"
            case .consistent: return "checkmark.circle"
            case .conflicted: return "exclamationmark.triangle"
            case .onlyCodex: return "chevron.left.circle"
            case .onlyClaude: return "chevron.right.circle"
            case .issues: return "wrench"
            }
        }
    }

    var filteredSkills: [SkillRecord] {
        var result = controller.skills
        switch selectedFilter {
        case .all: break
        case .consistent: result = result.filter { $0.syncStatus == .consistent }
        case .conflicted: result = result.filter { $0.syncStatus == .conflicted }
        case .onlyCodex: result = result.filter { $0.syncStatus == .onlyCodex }
        case .onlyClaude: result = result.filter { $0.syncStatus == .onlyClaude }
        case .issues: result = result.filter { !$0.healthWarnings.isEmpty }
        }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            result = result.filter { $0.name.lowercased().contains(q) || ($0.description ?? "").lowercased().contains(q) }
        }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            // 搜索
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("搜索技能...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.body)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }.buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(nsColor: .textBackgroundColor))
            .overlay(Divider(), alignment: .bottom)

            // 分类筛选
            List(selection: $selectedFilter) {
                ForEach(FilterCategory.allCases, id: \.self) { cat in
                    HStack(spacing: 8) {
                        Image(systemName: cat.icon)
                            .foregroundColor(categoryColor(cat))
                            .frame(width: 16)
                        Text(cat.rawValue).font(.body)
                        Spacer()
                        Text("\(count(for: cat))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .tag(cat)
                }
            }
            .listStyle(.sidebar)
            .frame(height: 220)

            Divider()

            // 技能列表
            List(selection: $selectedSkillName) {
                ForEach(filteredSkills) { skill in
                    SkillRowView(skill: skill)
                        .tag(skill.name)
                }
            }
            .listStyle(.plain)
            .overlay {
                if filteredSkills.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "puzzlepiece.extension").font(.title2).foregroundStyle(.tertiary)
                        Text("无匹配技能").foregroundStyle(.secondary).font(.caption)
                    }
                }
            }
        }
    }

    func count(for cat: FilterCategory) -> Int {
        switch cat {
        case .all: return controller.totalCount
        case .consistent: return controller.consistentCount
        case .conflicted: return controller.conflictedCount
        case .onlyCodex: return controller.onlyCodexCount
        case .onlyClaude: return controller.onlyClaudeCount
        case .issues: return controller.unhealthyCount
        }
    }

    func categoryColor(_ cat: FilterCategory) -> Color {
        switch cat {
        case .all: return .primary
        case .consistent: return .green
        case .conflicted: return .red
        case .onlyCodex: return .blue
        case .onlyClaude: return .orange
        case .issues: return .yellow
        }
    }
}

// MARK: - 详情面板
struct DashboardDetail: View {
    @Environment(AppController.self) private var controller
    let selectedSkillName: String?

    var selectedSkill: SkillRecord? {
        guard let name = selectedSkillName else { return nil }
        return controller.skills.first { $0.name == name }
    }

    var body: some View {
        if let skill = selectedSkill {
            SkillDetailView(skill: skill)
                .environment(controller)
                .id(skill.id)
        } else {
            VStack(spacing: 20) {
                HStack(spacing: 24) {
                    StatBadge(value: controller.totalCount, label: "总计", color: .primary)
                    StatBadge(value: controller.consistentCount, label: "一致", color: .green)
                    StatBadge(value: controller.conflictedCount, label: "冲突", color: .red)
                    StatBadge(value: controller.onlyCodexCount, label: "仅 Codex", color: .blue)
                    StatBadge(value: controller.onlyClaudeCount, label: "仅 Claude", color: .orange)
                    StatBadge(value: controller.unhealthyCount, label: "异常", color: .yellow)
                }

                Image(systemName: "puzzlepiece.extension")
                    .font(.system(size: 48)).foregroundStyle(.tertiary)
                Text("Skill Atlas").font(.title).fontWeight(.medium)
                Text("从左侧选择一个技能查看详情")
                    .font(.body).foregroundStyle(.tertiary)

                if controller.isScanning {
                    HStack(spacing: 8) {
                        ProgressView().progressViewStyle(.circular).scaleEffect(0.7)
                        Text("正在扫描技能目录...").foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - 技能行
struct SkillRowView: View {
    let skill: SkillRecord
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: skill.syncStatus.iconName)
                .foregroundColor(statusColor).font(.caption)
            VStack(alignment: .leading, spacing: 1) {
                Text(skill.name).font(.body).fontWeight(.medium).lineLimit(1)
                if let desc = skill.description, !desc.isEmpty {
                    Text(desc).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            if !skill.healthWarnings.isEmpty {
                Image(systemName: "exclamationmark.triangle.fill").font(.caption2).foregroundColor(.yellow)
            }
        }
        .padding(.vertical, 2)
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

// MARK: - 统计标签
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
