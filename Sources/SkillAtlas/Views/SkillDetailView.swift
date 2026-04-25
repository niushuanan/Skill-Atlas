import SwiftUI

struct SkillDetailView: View {
    @Environment(AppController.self) private var controller
    let skill: SkillRecord
    @State private var selectedDirection: SyncDirection = .codexToClaude
    @State private var selectedMode: SyncMode = .copy
    @State private var showDeleteConfirmation = false
    @State private var deleteTargetSide = "both"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                headerSection

                Divider()

                // Status overview
                statusSection

                Divider()

                // Side-by-side comparison
                comparisonSection

                Divider()

                // Structure info
                structureSection

                Divider()

                // Actions
                actionsSection
            }
            .padding()
        }
        .alert("Delete Skill", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    await controller.deleteSkill(skill: skill, side: deleteTargetSide)
                }
            }
        } message: {
            Text("This will create a backup first, then delete the skill from \(deleteTargetSide == "both" ? "both sides" : deleteTargetSide). You can restore from Backups.")
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack {
            Image(systemName: skill.syncStatus.iconName)
                .font(.largeTitle)
                .foregroundColor(statusColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(skill.name)
                    .font(.title2)
                    .fontWeight(.bold)

                if let desc = skill.description, !desc.isEmpty {
                    Text(desc)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(skill.syncStatus.rawValue)
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(statusColor.opacity(0.15))
                .foregroundColor(statusColor)
                .clipShape(Capsule())
        }
    }

    // MARK: - Status
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Status", systemImage: "info.circle")
                .font(.headline)

            HStack(spacing: 20) {
                SideStatusView(
                    side: "Codex",
                    exists: skill.codexExists,
                    path: skill.codexPath,
                    hash: skill.codexHash,
                    mtime: skill.codexMtime,
                    size: skill.codexSize,
                    color: .blue
                )
                SideStatusView(
                    side: "Claude",
                    exists: skill.claudeExists,
                    path: skill.claudePath,
                    hash: skill.claudeHash,
                    mtime: skill.claudeMtime,
                    size: skill.claudeSize,
                    color: .orange
                )
            }

            if !skill.healthWarnings.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Health", systemImage: "exclamationmark.triangle")
                        .foregroundColor(.yellow)
                    ForEach(skill.healthWarnings, id: \.self) { warning in
                        Text("  \(warning)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Comparison
    private var comparisonSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Comparison", systemImage: "arrow.left.arrow.right")
                .font(.headline)

            if skill.syncStatus == .consistent {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Both sides are identical")
                        .foregroundColor(.secondary)
                }
            } else if skill.syncStatus == .conflicted {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text("Hashes differ between sides")
                        .foregroundColor(.secondary)
                }
                if let cHash = skill.codexHash, let lHash = skill.claudeHash {
                    Text("Codex: \(cHash.prefix(16))...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Claude: \(lHash.prefix(16))...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if skill.syncStatus == .onlyCodex {
                Text("Only available in Codex")
                    .foregroundColor(.secondary)
            } else {
                Text("Only available in Claude")
                    .foregroundColor(.secondary)
            }

            if skill.isSymlinked {
                HStack {
                    Image(systemName: "link")
                        .foregroundColor(.purple)
                    Text("Claude side is a symlink to Codex")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Structure
    private var structureSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Directory Structure", systemImage: "folder")
                .font(.headline)

            if let structr = skill.directoryStructure {
                HStack(spacing: 16) {
                    StructTag(label: "scripts", active: structr.hasScripts)
                    StructTag(label: "assets", active: structr.hasAssets)
                    StructTag(label: "references", active: structr.hasReferences)
                    StructTag(label: "agents", active: structr.hasAgents)
                }
                HStack(spacing: 16) {
                    Text("Files: \(structr.fileCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Subdirs: \(structr.subdirectoryCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("No structure data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Actions
    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Actions", systemImage: "bolt.fill")
                .font(.headline)

            // Sync controls
            if skill.syncStatus != .consistent {
                GroupBox("Sync") {
                    VStack(spacing: 8) {
                        Picker("Direction", selection: $selectedDirection) {
                            ForEach(SyncDirection.allCases, id: \.self) { dir in
                                Text(dir.rawValue).tag(dir)
                            }
                        }
                        .pickerStyle(.segmented)

                        Picker("Mode", selection: $selectedMode) {
                            ForEach(SyncMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        HStack {
                            Spacer()
                            Button("Sync Now") {
                                Task {
                                    await controller.syncSkill(
                                        skill: skill,
                                        direction: selectedDirection,
                                        mode: selectedMode
                                    )
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(controller.isSyncing)
                        }
                    }
                    .padding(8)
                }
            }

            // Delete options
            GroupBox("Delete") {
                VStack(spacing: 8) {
                    Picker("Delete from", selection: $deleteTargetSide) {
                        Text("Both sides").tag("both")
                        if skill.codexExists { Text("Codex only").tag("codex") }
                        if skill.claudeExists { Text("Claude only").tag("claude") }
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        Text("Backup will be created automatically")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Delete", role: .destructive) {
                            showDeleteConfirmation = true
                        }
                        .disabled(controller.isSyncing)
                    }
                }
                .padding(8)
            }
        }
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

// MARK: - Side Status
struct SideStatusView: View {
    let side: String
    let exists: Bool
    let path: String?
    let hash: String?
    let mtime: Date?
    let size: Int64?
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(exists ? color : Color.gray)
                    .frame(width: 8, height: 8)
                Text(side)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            if exists {
                Text(size != nil ? "\(ByteCountFormatter.string(fromByteCount: size!, countStyle: .file))" : "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(mtime != nil ? mtime!.formatted() : "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let p = path {
                    Text(p)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            } else {
                Text("Not present")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
            }

            if let h = hash {
                Text("Hash: \(h.prefix(12))...")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Struct Tag
struct StructTag: View {
    let label: String
    let active: Bool

    var body: some View {
        Text(label)
            .font(.caption)
            .foregroundColor(active ? .primary : .secondary.opacity(0.5))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(active ? Color.accentColor.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(active ? Color.accentColor.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
            )
    }
}
