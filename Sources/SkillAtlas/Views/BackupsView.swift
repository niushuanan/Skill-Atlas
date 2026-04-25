import SwiftUI

struct BackupsView: View {
    @Environment(AppController.self) private var controller

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.title2)
                Text("Backup History")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()

                if !controller.backups.isEmpty {
                    Button("Cleanup Old") {
                        Task { await controller.cleanupOldBackups() }
                    }
                    .font(.caption)
                }
            }
            .padding()

            Divider()

            // Backup list
            backupList
        }
    }

    // MARK: - Backup List
    private var backupList: some View {
        Group {
            if controller.backups.isEmpty {
                ContentUnavailableView(
                    "No Backups",
                    systemImage: "clock.badge.questionmark",
                    description: Text("Backups are created automatically when you delete or sync skills")
                )
            } else {
                List(controller.backups) { backup in
                    BackupRowView(backup: backup)
                        .environment(controller)
                }
                .listStyle(.inset)
            }
        }
    }
}

// MARK: - Backup Row
struct BackupRowView: View {
    @Environment(AppController.self) private var controller
    let backup: BackupRecord
    @State private var showRestoreConfirmation = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: backupIcon)
                .font(.title3)
                .foregroundColor(backupColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(backup.skillName)
                    .font(.body)
                    .fontWeight(.medium)

                Text(backup.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Text(backup.operationType)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(Capsule())

                    Text("\(backup.sourcePaths.count) file(s)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button("Restore") {
                showRestoreConfirmation = true
            }
            .buttonStyle(.bordered)
            .font(.caption)

            Button("Delete") {
                Task { await controller.deleteBackup(backupID: backup.id) }
            }
            .buttonStyle(.borderless)
            .font(.caption)
            .foregroundColor(.red)
        }
        .padding(.vertical, 4)
        .alert("Restore Backup", isPresented: $showRestoreConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Restore") {
                Task { await controller.restoreBackup(backup) }
            }
        } message: {
            Text("This will restore '\(backup.skillName)' from backup created \(backup.formattedDate). Existing files will be overwritten.")
        }
    }

    private var backupIcon: String {
        switch backup.operationType {
        case "delete_codex", "delete_claude", "delete_both":
            return "trash.slash"
        case "sync_overwrite":
            return "arrow.triangle.2.circlepath"
        default:
            return "clock"
        }
    }

    private var backupColor: Color {
        switch backup.operationType {
        case "delete_codex", "delete_claude", "delete_both":
            return .orange
        case "sync_overwrite":
            return .blue
        default:
            return .gray
        }
    }
}
