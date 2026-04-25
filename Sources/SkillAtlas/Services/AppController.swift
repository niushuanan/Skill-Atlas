import Foundation
import SwiftUI

@MainActor @Observable
final class AppController {
    // MARK: - Published State
    var skills: [SkillRecord] = []
    var backups: [BackupRecord] = []
    var discoverResults: [DiscoverResult] = []
    var settings = AppSettings.default
    var isScanning = false
    var isSyncing = false
    var errorMessage: String?
    var toastMessage: String?
    var selectedSkill: SkillRecord?
    var selectedTab: Tab = .dashboard

    enum Tab: String, CaseIterable, Sendable {
        case dashboard = "Dashboard"
        case sync = "Sync"
        case discover = "Discover"
        case backups = "Backups"
        case settings = "Settings"

        var icon: String {
            switch self {
            case .dashboard: return "square.grid.2x2"
            case .sync: return "arrow.triangle.2.circlepath"
            case .discover: return "magnifyingglass"
            case .backups: return "clock.arrow.circlepath"
            case .settings: return "gearshape"
            }
        }
    }

    // MARK: - Services
    private let scanService = ScanService()
    private let backupService: BackupService
    private let syncService: SyncService
    private let settingsManager: SettingsManager
    private let discoveryService = DiscoveryService()

    init() {
        let appSettings = AppSettings.default
        self.settings = appSettings
        self.backupService = BackupService(backupRoot: appSettings.backupRoot)
        self.syncService = SyncService(backupService: backupService)
        self.settingsManager = SettingsManager(settingsURL: appSettings.settingsURL)

        // Load persisted settings
        Task {
            self.settings = await settingsManager.load()
            await scan()
            await refreshBackups()
        }
    }

    // MARK: - Scan
    func scan() async {
        isScanning = true
        errorMessage = nil
        do {
            skills = try await scanService.scan(
                codexPath: settings.codexSkillsPath,
                claudePath: settings.claudeSkillsPath
            )
        } catch {
            errorMessage = "Scan failed: \(error.localizedDescription)"
        }
        isScanning = false
    }

    // MARK: - Sync
    func previewSync(skill: SkillRecord, direction: SyncDirection) -> SyncPreview {
        // Use syncService preview — need to handle actor crossing
        // Since we're on MainActor, we can call the sync actor method
        Task {
            let preview = await syncService.previewSync(skill: skill, direction: direction)
            await MainActor.run {
                // Store or use preview
            }
        }
        return SyncPreview(skillName: skill.name, direction: direction, sourcePath: "", targetPath: "", changes: [], fileCount: 0, warnings: [])
    }

    func syncSkill(skill: SkillRecord, direction: SyncDirection, mode: SyncMode) async {
        isSyncing = true
        errorMessage = nil
        do {
            _ = try await syncService.sync(skill: skill, direction: direction, mode: mode)
            toastMessage = "Synced '\(skill.name)' \(direction.rawValue)"
            // Refresh
            await scan()
            await refreshBackups()
        } catch {
            errorMessage = "Sync failed: \(error.localizedDescription)"
        }
        isSyncing = false
    }

    func batchSync(skills: [SkillRecord], direction: SyncDirection, mode: SyncMode) async {
        isSyncing = true
        errorMessage = nil
        do {
            let results = try await syncService.batchSync(skills: skills, direction: direction, mode: mode)
            let successCount = results.filter { $0.success }.count
            let failCount = results.filter { !$0.success }.count
            toastMessage = "Batch sync: \(successCount) succeeded, \(failCount) failed"
            await scan()
            await refreshBackups()
        } catch {
            errorMessage = "Batch sync failed: \(error.localizedDescription)"
        }
        isSyncing = false
    }

    // MARK: - Delete
    func deleteSkill(skill: SkillRecord, side: String) async {
        let paths: [String]
        let displaySide: String

        if side == "codex", let p = skill.codexPath {
            paths = [p]
            displaySide = "Codex"
        } else if side == "claude", let p = skill.claudePath {
            paths = [p]
            displaySide = "Claude"
        } else {
            paths = [skill.codexPath, skill.claudePath].compactMap { $0 }
            displaySide = "both"
        }

        guard !paths.isEmpty else { return }

        // Create backup first
        do {
            _ = try await backupService.createBackup(
                skillName: skill.name,
                paths: paths,
                operationType: "delete_\(side)"
            )
        } catch {
            errorMessage = "Backup failed before delete: \(error.localizedDescription)"
            return
        }

        // Now delete
        for path in paths {
            do {
                try FileManager.default.removeItem(atPath: path)
            } catch {
                errorMessage = "Failed to delete \(path): \(error.localizedDescription)"
            }
        }

        toastMessage = "Deleted '\(skill.name)' from \(displaySide) (backup created)"
        await scan()
        await refreshBackups()
    }

    // MARK: - Backups
    func refreshBackups() async {
        backups = await backupService.listBackups()
    }

    func restoreBackup(_ backup: BackupRecord) async {
        do {
            try await backupService.restore(backup: backup)
            toastMessage = "Restored '\(backup.skillName)' from backup"
            await scan()
            await refreshBackups()
        } catch {
            errorMessage = "Restore failed: \(error.localizedDescription)"
        }
    }

    func deleteBackup(backupID: String) async {
        do {
            try await backupService.deleteBackup(backupID: backupID)
            await refreshBackups()
        } catch {
            errorMessage = "Failed to delete backup: \(error.localizedDescription)"
        }
    }

    func cleanupOldBackups() async {
        await backupService.cleanupOldBackups(retentionDays: settings.backupRetentionDays)
        await refreshBackups()
    }

    // MARK: - Discover
    func searchDiscover(query: String) async {
        discoverResults = await discoveryService.discover(query: query, installedSkills: skills)
    }

    func installDiscovered(result: DiscoverResult, targetSide: String) async {
        // Attempt to download from source
        toastMessage = "Install feature: \(result.name) → \(targetSide)"
        // In MVP, this would involve git clone or download
        await scan()
    }

    // MARK: - Settings
    func saveSettings() async {
        do {
            try await settingsManager.save(settings)
            toastMessage = "Settings saved"
        } catch {
            errorMessage = "Failed to save settings: \(error.localizedDescription)"
        }
    }

    func resetSettings() async {
        do {
            try await settingsManager.reset()
            settings = .default
            toastMessage = "Settings reset to default"
        } catch {
            errorMessage = "Failed to reset settings: \(error.localizedDescription)"
        }
    }

    // MARK: - Counts
    var totalCount: Int { skills.count }
    var consistentCount: Int { skills.filter { $0.syncStatus == .consistent }.count }
    var conflictedCount: Int { skills.filter { $0.syncStatus == .conflicted }.count }
    var onlyCodexCount: Int { skills.filter { $0.syncStatus == .onlyCodex }.count }
    var onlyClaudeCount: Int { skills.filter { $0.syncStatus == .onlyClaude }.count }
    var unhealthyCount: Int { skills.filter { !$0.healthWarnings.isEmpty }.count }
}
