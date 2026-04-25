import SwiftUI

struct ContentView: View {
    @Environment(AppController.self) private var controller
    @State private var selectedFilter = DashboardSidebar.FilterCategory.all
    @State private var selectedSkillName: String?
    @State private var showBackups = false

    var body: some View {
        NavigationSplitView {
            DashboardSidebar(
                selectedFilter: $selectedFilter,
                selectedSkillName: $selectedSkillName
            )
        } detail: {
            DashboardDetail(selectedSkillName: selectedSkillName)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItemGroup {
                Button(action: { Task { await controller.scan() } }) {
                    if controller.isScanning {
                        ProgressView().progressViewStyle(.circular).scaleEffect(0.5)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(controller.isScanning)
                .help("扫描技能目录")

                Button(action: { showBackups = true }) {
                    Image(systemName: "clock.arrow.circlepath")
                }
                .help("备份记录")
            }
        }
        .sheet(isPresented: $showBackups) {
            BackupsSheet()
                .environment(controller)
                .frame(minWidth: 480, minHeight: 360)
        }
        .overlay(alignment: .bottom) {
            if let toast = controller.toastMessage {
                Text(toast)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        Task { try? await Task.sleep(nanoseconds: 3_000_000_000)
                            withAnimation { controller.toastMessage = nil } }
                    }
            }
        }
        .overlay(alignment: .center) {
            if let error = controller.errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill").font(.largeTitle).foregroundColor(.yellow)
                    Text(error).multilineTextAlignment(.center)
                    Button("关闭") { controller.errorMessage = nil }
                }
                .padding().background(.ultraThickMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12)).shadow(radius: 10)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: controller.toastMessage != nil)
    }
}

// MARK: - 备份列表（简化 sheet）
struct BackupsSheet: View {
    @Environment(AppController.self) private var controller
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if controller.backups.isEmpty {
                    ContentUnavailableView(
                        "暂无备份",
                        systemImage: "clock.badge.questionmark",
                        description: Text("删除或同步技能时会自动创建备份")
                    )
                } else {
                    List(controller.backups) { backup in
                        HStack(spacing: 12) {
                            Image(systemName: backupIcon(backup)).foregroundColor(.secondary).font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(backup.skillName).font(.body).fontWeight(.medium)
                                Text("\(backup.formattedDate) · \(backup.sourcePaths.count) 个文件")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("恢复") {
                                Task { await controller.restoreBackup(backup) }
                            }
                            .buttonStyle(.bordered).font(.caption)
                            Button("删除") {
                                Task { await controller.deleteBackup(backupID: backup.id) }
                            }
                            .buttonStyle(.borderless).font(.caption).foregroundColor(.red)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem {
                    Button("清理过期") {
                        Task { await controller.cleanupOldBackups() }
                    }.font(.caption)
                }
            }
            .navigationTitle("备份记录")
        }
    }

    func backupIcon(_ backup: BackupRecord) -> String {
        backup.operationType.hasPrefix("delete") ? "trash.slash" : "arrow.triangle.2.circlepath"
    }
}
