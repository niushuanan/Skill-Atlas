import Foundation

actor BackupService {
    private let backupRoot: URL

    init(backupRoot: URL) {
        self.backupRoot = backupRoot
        try? FileManager.default.createDirectory(at: backupRoot,
                                                  withIntermediateDirectories: true)
    }

    // MARK: - Create Backup
    func createBackup(skillName: String, paths: [String], operationType: String) throws -> BackupRecord {
        let fm = FileManager.default
        let backupID = UUID().uuidString
        let backupDir = backupRoot.appendingPathComponent("\(skillName)_\(backupID)")
        try fm.createDirectory(at: backupDir, withIntermediateDirectories: true)

        var backedUpPaths: [String] = []
        for sourcePath in paths {
            let sourceURL = URL(fileURLWithPath: sourcePath)
            let itemName = sourceURL.lastPathComponent
            let destURL = backupDir.appendingPathComponent(itemName)

            if fm.fileExists(atPath: sourcePath) {
                try fm.copyItem(at: sourceURL, to: destURL)
                backedUpPaths.append(sourcePath)
            }
        }

        let record = BackupRecord(
            id: backupID,
            skillName: skillName,
            operationType: operationType,
            createdAt: Date(),
            sourcePaths: backedUpPaths,
            backupDir: backupDir.path,
            side: backedUpPaths.isEmpty ? "unknown" : "both"
        )

        // Save record metadata
        let recordURL = backupDir.appendingPathComponent("backup.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(record) {
            try data.write(to: recordURL)
        }

        return record
    }

    // MARK: - List Backups
    func listBackups() -> [BackupRecord] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(at: backupRoot,
                                                          includingPropertiesForKeys: [.creationDateKey],
                                                          options: [.skipsHiddenFiles]) else {
            return []
        }

        let records: [BackupRecord] = contents.compactMap { dirURL in
            let recordURL = dirURL.appendingPathComponent("backup.json")
            guard let data = try? Data(contentsOf: recordURL),
                  let record = try? JSONDecoder().decode(BackupRecord.self, from: data) else {
                // Incomplete backup, skip
                return nil
            }
            return record
        }

        return records.sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Restore Backup
    func restore(backup: BackupRecord) throws {
        let fm = FileManager.default
        let backupDirURL = URL(fileURLWithPath: backup.backupDir)

        for sourcePath in backup.sourcePaths {
            let sourceURL = URL(fileURLWithPath: sourcePath)
            let itemName = sourceURL.lastPathComponent
            let backupItemURL = backupDirURL.appendingPathComponent(itemName)

            guard fm.fileExists(atPath: backupItemURL.path) else { continue }

            // Create parent dir if needed
            try fm.createDirectory(at: sourceURL.deletingLastPathComponent(),
                                   withIntermediateDirectories: true)

            // Remove existing if any
            if fm.fileExists(atPath: sourcePath) {
                try fm.removeItem(at: sourceURL)
            }

            try fm.copyItem(at: backupItemURL, to: sourceURL)
        }
    }

    // MARK: - Delete Backup
    func deleteBackup(backupID: String) throws {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(at: backupRoot,
                                                          includingPropertiesForKeys: nil) else { return }

        for dirURL in contents {
            let recordURL = dirURL.appendingPathComponent("backup.json")
            if let data = try? Data(contentsOf: recordURL),
               let record = try? JSONDecoder().decode(BackupRecord.self, from: data),
               record.id == backupID {
                try fm.removeItem(at: dirURL)
                return
            }
        }
    }

    // MARK: - Cleanup Old Backups
    func cleanupOldBackups(retentionDays: Int) {
        let cutoff = Date().addingTimeInterval(-Double(retentionDays) * 86400)
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(at: backupRoot,
                                                          includingPropertiesForKeys: [.creationDateKey]) else { return }

        for dirURL in contents {
            let recordURL = dirURL.appendingPathComponent("backup.json")
            if let data = try? Data(contentsOf: recordURL),
               let record = try? JSONDecoder().decode(BackupRecord.self, from: data),
               record.createdAt < cutoff {
                try? fm.removeItem(at: dirURL)
            }
        }
    }

    // MARK: - Get Backup Count
    func backupCount() -> Int {
        listBackups().count
    }
}
