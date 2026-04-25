import SwiftUI

struct SyncView: View {
    @Environment(AppController.self) private var controller
    @State private var selectedDirection: SyncDirection = .codexToClaude
    @State private var selectedMode: SyncMode = .copy
    @State private var selectedSkills = Set<String>()
    @State private var showBatchConfirmation = false

    var syncableSkills: [SkillRecord] {
        controller.skills.filter { $0.syncStatus != .consistent }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Controls
            controlBar
                .padding()
                .background(.background)

            Divider()

            // Syncable list
            syncableList
        }
        .toolbar {
            ToolbarItem {
                Button("Refresh") {
                    Task { await controller.scan() }
                }
            }
        }
        .alert("Batch Sync", isPresented: $showBatchConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Sync \(selectedSkills.count) Skills") {
                let toSync = syncableSkills.filter { selectedSkills.contains($0.name) }
                Task {
                    await controller.batchSync(skills: toSync, direction: selectedDirection, mode: selectedMode)
                    selectedSkills.removeAll()
                }
            }
        } message: {
            Text("This will sync \(selectedSkills.count) skill(s) from \(selectedDirection.rawValue). Backups will be created automatically.")
        }
    }

    // MARK: - Control Bar
    private var controlBar: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.title2)
                Text("Sync Center")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()

                // Progress indicator
                if controller.isSyncing {
                    HStack(spacing: 6) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.7)
                        Text("Syncing...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack(spacing: 16) {
                // Direction
                VStack(alignment: .leading, spacing: 4) {
                    Text("Direction").font(.caption).foregroundStyle(.secondary)
                    Picker("", selection: $selectedDirection) {
                        ForEach(SyncDirection.allCases, id: \.self) { dir in
                            Text(dir.rawValue).tag(dir)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                // Mode
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mode").font(.caption).foregroundStyle(.secondary)
                    Picker("", selection: $selectedMode) {
                        ForEach(SyncMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                Spacer()

                // Batch sync button
                if !selectedSkills.isEmpty {
                    Button("Sync Selected (\(selectedSkills.count))") {
                        showBatchConfirmation = true
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(controller.isSyncing)
                }
            }
        }
    }

    // MARK: - Syncable List
    private var syncableList: some View {
        Group {
            if syncableSkills.isEmpty {
                ContentUnavailableView(
                    "All Synced",
                    systemImage: "checkmark.circle.fill",
                    description: Text("All skills are consistent between Codex and Claude")
                )
            } else {
                List(syncableSkills) { skill in
                    SyncRowView(
                        skill: skill,
                        isSelected: selectedSkills.contains(skill.name),
                        onToggle: { toggled in
                            if toggled {
                                selectedSkills.insert(skill.name)
                            } else {
                                selectedSkills.remove(skill.name)
                            }
                        }
                    )
                }
                .listStyle(.inset)
            }
        }
    }
}

// MARK: - Sync Row
struct SyncRowView: View {
    @Environment(AppController.self) private var controller
    let skill: SkillRecord
    let isSelected: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: skill.syncStatus.iconName)
                .foregroundColor(statusColor)

            Toggle(isOn: Binding(
                get: { isSelected },
                set: { onToggle($0) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(skill.name)
                        .font(.body)
                        .fontWeight(.medium)

                    Text(skill.syncStatus.rawValue)
                        .font(.caption)
                        .foregroundColor(statusColor)
                }
            }
            .toggleStyle(.checkbox)

            Spacer()

            // Quick sync button
            Button("Sync → Claude") {
                Task {
                    await controller.syncSkill(skill: skill, direction: .codexToClaude, mode: .copy)
                }
            }
            .buttonStyle(.borderless)
            .font(.caption)
            .disabled(!skill.codexExists || controller.isSyncing)

            Button("Sync → Codex") {
                Task {
                    await controller.syncSkill(skill: skill, direction: .claudeToCodex, mode: .copy)
                }
            }
            .buttonStyle(.borderless)
            .font(.caption)
            .disabled(!skill.claudeExists || controller.isSyncing)

            Button("Diff") {
                controller.selectedSkill = skill
            }
            .buttonStyle(.borderless)
            .font(.caption)
            .sheet(item: Bindable(controller).selectedSkill) { skill in
                DiffPreviewView(skill: skill)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        switch skill.syncStatus {
        case .conflicted: return .red
        case .onlyCodex: return .blue
        case .onlyClaude: return .orange
        default: return .gray
        }
    }
}
