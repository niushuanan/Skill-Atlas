import Foundation
import SwiftUI

@MainActor @Observable
final class AppController {
    // MARK: - 状态
    var skills: [SkillRecord] = []
    var backups: [BackupRecord] = []
    var settings = AppSettings.default
    var isScanning = false
    var isSyncing = false
    var errorMessage: String?
    var toastMessage: String?

    // MARK: - Services
    private let scanService = ScanService()
    private let backupService: BackupService
    private let syncService: SyncService
    private let settingsManager: SettingsManager

    init() {
        let appSettings = AppSettings.default
        self.settings = appSettings
        self.backupService = BackupService(backupRoot: appSettings.backupRoot)
        self.syncService = SyncService(backupService: backupService)
        self.settingsManager = SettingsManager(settingsURL: appSettings.settingsURL)

        Task {
            self.settings = await settingsManager.load()
            await scan()
            await refreshBackups()
        }
    }

    // MARK: - 扫描
    func scan() async {
        isScanning = true
        errorMessage = nil
        do {
            skills = try await scanService.scan(
                codexPath: settings.codexSkillsPath,
                claudePath: settings.claudeSkillsPath
            )
        } catch {
            errorMessage = "扫描失败: \(error.localizedDescription)"
        }
        isScanning = false
    }

    // MARK: - 同步
    func syncSkill(skill: SkillRecord, direction: SyncDirection, mode: SyncMode) async {
        isSyncing = true
        errorMessage = nil
        do {
            _ = try await syncService.sync(skill: skill, direction: direction, mode: mode)
            toastMessage = "已同步「\(skill.name)」"
            await scan()
            await refreshBackups()
        } catch {
            errorMessage = "同步失败: \(error.localizedDescription)"
        }
        isSyncing = false
    }

    func batchSync(skills: [SkillRecord], direction: SyncDirection, mode: SyncMode) async {
        isSyncing = true
        errorMessage = nil
        do {
            let results = try await syncService.batchSync(skills: skills, direction: direction, mode: mode)
            let ok = results.filter { $0.success }.count
            let fail = results.filter { !$0.success }.count
            toastMessage = "批量同步完成: \(ok) 成功, \(fail) 失败"
            await scan()
            await refreshBackups()
        } catch {
            errorMessage = "批量同步失败: \(error.localizedDescription)"
        }
        isSyncing = false
    }

    // MARK: - 删除
    func deleteSkill(skill: SkillRecord, side: String) async {
        let paths: [String]
        if side == "codex", let p = skill.codexPath {
            paths = [p]
        } else if side == "claude", let p = skill.claudePath {
            paths = [p]
        } else {
            paths = [skill.codexPath, skill.claudePath].compactMap { $0 }
        }
        guard !paths.isEmpty else { return }

        // 先备份再删除
        do {
            _ = try await backupService.createBackup(
                skillName: skill.name, paths: paths, operationType: "delete_\(side)"
            )
        } catch {
            errorMessage = "备份失败，已取消删除: \(error.localizedDescription)"
            return
        }
        for path in paths {
            try? FileManager.default.removeItem(atPath: path)
        }
        toastMessage = "已删除「\(skill.name)」(备份已创建)"
        await scan()
        await refreshBackups()
    }

    // MARK: - 备份
    func refreshBackups() async {
        backups = await backupService.listBackups()
    }

    func restoreBackup(_ backup: BackupRecord) async {
        do {
            try await backupService.restore(backup: backup)
            toastMessage = "已恢复「\(backup.skillName)」"
            await scan()
            await refreshBackups()
        } catch {
            errorMessage = "恢复失败: \(error.localizedDescription)"
        }
    }

    func deleteBackup(backupID: String) async {
        do {
            try await backupService.deleteBackup(backupID: backupID)
            await refreshBackups()
        } catch {
            errorMessage = "删除备份失败: \(error.localizedDescription)"
        }
    }

    func cleanupOldBackups() async {
        await backupService.cleanupOldBackups(retentionDays: settings.backupRetentionDays)
        await refreshBackups()
    }

    // MARK: - 设置
    func saveSettings() async {
        do {
            try await settingsManager.save(settings)
            toastMessage = "设置已保存"
        } catch {
            errorMessage = "保存设置失败: \(error.localizedDescription)"
        }
    }

    // MARK: - 统计
    var totalCount: Int { skills.count }
    var consistentCount: Int { skills.filter { $0.syncStatus == .consistent }.count }
    var conflictedCount: Int { skills.filter { $0.syncStatus == .conflicted }.count }
    var onlyCodexCount: Int { skills.filter { $0.syncStatus == .onlyCodex }.count }
    var onlyClaudeCount: Int { skills.filter { $0.syncStatus == .onlyClaude }.count }
    var unhealthyCount: Int { skills.filter { !$0.healthWarnings.isEmpty }.count }
}
