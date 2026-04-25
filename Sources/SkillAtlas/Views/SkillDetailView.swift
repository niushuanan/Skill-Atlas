import SwiftUI

struct SkillDetailView: View {
    @Environment(AppController.self) private var controller
    let skill: SkillRecord
    @State private var syncDirection: SyncDirection = .codexToClaude
    @State private var syncMode: SyncMode = .copy
    @State private var confirmDelete = false
    @State private var deleteSide = "both"
    @State private var showAllBackups = false

    var skillBackups: [BackupRecord] {
        controller.backups.filter { $0.skillName == skill.name }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerSection
                Divider()
                statusSection
                Divider()
                pathsSection
                Divider()
                structureSection
                Divider()
                syncSection
                Divider()
                dangerSection
                Divider()
                backupsSection
            }
            .padding()
        }
        .alert("确认删除", isPresented: $confirmDelete) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                Task { await controller.deleteSkill(skill: skill, side: deleteSide) }
            }
        } message: {
            Text("将自动创建备份，然后从\(deleteSide == "both" ? "两端" : deleteSide == "codex" ? "Codex" : "Claude")删除「\(skill.name)」。可在备份记录中恢复。")
        }
        .sheet(isPresented: $showAllBackups) {
            skillBackupList
                .frame(minWidth: 400, minHeight: 300)
        }
    }

    // MARK: - 头部
    private var headerSection: some View {
        HStack {
            Image(systemName: skill.syncStatus.iconName)
                .font(.largeTitle).foregroundColor(statusColor)
            VStack(alignment: .leading, spacing: 4) {
                Text(skill.name).font(.title2).fontWeight(.bold)
                if let desc = skill.description, !desc.isEmpty {
                    Text(desc).font(.body).foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                statusBadge
                if skill.isSymlinked {
                    Label("符号链接", systemImage: "link")
                        .font(.caption).foregroundStyle(.tertiary)
                }
            }
        }
    }

    private var statusBadge: some View {
        Text(skill.syncStatus.rawValue)
            .font(.caption).fontWeight(.semibold)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(statusColor.opacity(0.15))
            .foregroundColor(statusColor)
            .clipShape(Capsule())
    }

    // MARK: - 状态
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("状态", systemImage: "info.circle").font(.headline)

            HStack(spacing: 16) {
                sideCard("Codex", exists: skill.codexExists, path: skill.codexPath,
                         hash: skill.codexHash, mtime: skill.codexMtime, color: .blue)
                sideCard("Claude", exists: skill.claudeExists, path: skill.claudePath,
                         hash: skill.claudeHash, mtime: skill.claudeMtime, color: .orange)
            }

            if !skill.healthWarnings.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("健康检查", systemImage: "exclamationmark.triangle").foregroundColor(.yellow)
                    ForEach(skill.healthWarnings, id: \.self) { w in
                        Text("· \(w)").font(.caption).foregroundColor(.secondary)
                    }
                }.padding(.top, 4)
            }
        }
    }

    // MARK: - 路径
    private var pathsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("路径", systemImage: "folder").font(.headline)
            if let p = skill.codexPath {
                HStack(alignment: .top) {
                    Text("Codex:").font(.caption).foregroundStyle(.secondary).frame(width: 50, alignment: .trailing)
                    Text(p).font(.caption).foregroundStyle(.tertiary).textSelection(.enabled)
                }
            }
            if let p = skill.claudePath {
                HStack(alignment: .top) {
                    Text("Claude:").font(.caption).foregroundStyle(.secondary).frame(width: 50, alignment: .trailing)
                    Text(p).font(.caption).foregroundStyle(.tertiary).textSelection(.enabled)
                }
            }
        }
    }

    // MARK: - 目录结构
    private var structureSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("目录结构", systemImage: "list.bullet").font(.headline)
            if let s = skill.directoryStructure {
                HStack(spacing: 12) {
                    dirTag("scripts", active: s.hasScripts)
                    dirTag("assets", active: s.hasAssets)
                    dirTag("references", active: s.hasReferences)
                    dirTag("agents", active: s.hasAgents)
                }
                Text("\(s.fileCount) 个文件 · \(s.subdirectoryCount) 个子目录")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 同步
    private var syncSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("同步", systemImage: "arrow.triangle.2.circlepath").font(.headline)

            if skill.syncStatus == .consistent && !skill.isSymlinked {
                HStack {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                    Text("两端一致").foregroundStyle(.secondary)
                }
            } else if skill.isSymlinked {
                HStack {
                    Image(systemName: "link").foregroundColor(.purple)
                    Text("Claude 端是符号链接，无需同步").foregroundStyle(.secondary)
                }
            } else {
                GroupBox {
                    VStack(spacing: 8) {
                        Picker("方向", selection: $syncDirection) {
                            ForEach(SyncDirection.allCases, id: \.self) { d in
                                Text(directionLabel(d)).tag(d)
                            }
                        }
                        .pickerStyle(.segmented)

                        Picker("模式", selection: $syncMode) {
                            ForEach(SyncMode.allCases, id: \.self) { m in
                                Text(modeLabel(m)).tag(m)
                            }
                        }
                        .pickerStyle(.segmented)

                        HStack {
                            Spacer()
                            Button("执行同步") {
                                Task { await controller.syncSkill(skill: skill, direction: syncDirection, mode: syncMode) }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(controller.isSyncing)
                        }
                    }
                    .padding(8)
                }
            }
        }
    }

    // MARK: - 危险操作
    private var dangerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("危险操作", systemImage: "exclamationmark.shield").font(.headline).foregroundColor(.red)

            GroupBox {
                VStack(spacing: 8) {
                    HStack {
                        Text("删除范围:").font(.caption).foregroundStyle(.secondary)
                        Picker("", selection: $deleteSide) {
                            Text("两端").tag("both")
                            if skill.codexExists { Text("仅 Codex").tag("codex") }
                            if skill.claudeExists { Text("仅 Claude").tag("claude") }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                    HStack {
                        Text("删除前会自动创建备份").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("删除", role: .destructive) { confirmDelete = true }
                            .disabled(controller.isSyncing)
                    }
                }
                .padding(8)
            }
        }
    }

    // MARK: - 备份记录
    private var backupsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("备份记录", systemImage: "clock.arrow.circlepath").font(.headline)
                Spacer()
                if !skillBackups.isEmpty {
                    Button("查看全部") { showAllBackups = true }
                        .font(.caption)
                }
            }

            if skillBackups.isEmpty {
                Text("暂无备份").font(.caption).foregroundStyle(.secondary).italic()
            } else {
                ForEach(Array(skillBackups.prefix(5))) { backup in
                    HStack {
                        Image(systemName: "doc.text").font(.caption).foregroundStyle(.secondary)
                        Text(backup.formattedDate).font(.caption).foregroundStyle(.secondary)
                        Text("(\(backup.sourcePaths.count) 文件)").font(.caption2).foregroundStyle(.tertiary)
                        Spacer()
                        Button("恢复") {
                            Task { await controller.restoreBackup(backup) }
                        }
                        .font(.caption).buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    // MARK: - 备份列表 sheet
    private var skillBackupList: some View {
        NavigationStack {
            List(skillBackups) { backup in
                HStack {
                    Text(backup.formattedDate).font(.body)
                    Text("(\(backup.sourcePaths.count) 文件)").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("恢复") { Task { await controller.restoreBackup(backup) } }
                        .buttonStyle(.bordered).font(.caption)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { showAllBackups = false }
                }
            }
            .navigationTitle("\(skill.name) 备份")
        }
    }

    // MARK: - Helpers
    private var statusColor: Color {
        switch skill.syncStatus {
        case .consistent: return .green
        case .conflicted: return .red
        case .onlyCodex: return .blue
        case .onlyClaude: return .orange
        }
    }

    private func directionLabel(_ d: SyncDirection) -> String {
        switch d {
        case .codexToClaude: return "Codex → Claude"
        case .claudeToCodex: return "Claude → Codex"
        }
    }

    private func modeLabel(_ m: SyncMode) -> String {
        switch m {
        case .copy: return "复制"
        case .symlink: return "符号链接"
        }
    }
}

// MARK: - 侧边卡片
func sideCard(_ title: String, exists: Bool, path: String?, hash: String?, mtime: Date?, color: Color) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        HStack {
            Circle().fill(exists ? color : .gray).frame(width: 8, height: 8)
            Text(title).font(.subheadline).fontWeight(.semibold)
        }
        if exists {
            if let p = path { Text(p).font(.caption2).foregroundStyle(.tertiary).lineLimit(1).truncationMode(.middle) }
            if let t = mtime { Text(t.formatted()).font(.caption).foregroundStyle(.secondary) }
            if let h = hash { Text("Hash: \(h.prefix(12))...").font(.caption2).foregroundStyle(.tertiary) }
        } else {
            Text("不存在").font(.caption).foregroundStyle(.secondary).italic()
        }
    }
    .padding(8).frame(maxWidth: .infinity, alignment: .leading)
    .background(color.opacity(0.05)).clipShape(RoundedRectangle(cornerRadius: 6))
}

// MARK: - 目录标签
func dirTag(_ label: String, active: Bool) -> some View {
    Text(label)
        .font(.caption)
        .foregroundColor(active ? .primary : .secondary.opacity(0.5))
        .padding(.horizontal, 6).padding(.vertical, 2)
        .background(active ? Color.accentColor.opacity(0.1) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4)
            .stroke(active ? Color.accentColor.opacity(0.3) : .gray.opacity(0.2), lineWidth: 1))
}
