import Foundation

actor SyncService {
    let backupService: BackupService

    init(backupService: BackupService) {
        self.backupService = backupService
    }

    enum SyncError: LocalizedError {
        case sourceNotFound(String)
        case targetAlreadyExists(String)
        case copyFailed(String)
        case symlinkCreationFailed(String)
        case invalidPath(String)

        var errorDescription: String? {
            switch self {
            case .sourceNotFound(let name): return "Source skill not found: \(name)"
            case .targetAlreadyExists(let name): return "Target already exists: \(name)"
            case .copyFailed(let detail): return "Copy failed: \(detail)"
            case .symlinkCreationFailed(let detail): return "Symlink creation failed: \(detail)"
            case .invalidPath(let detail): return "Invalid path: \(detail)"
            }
        }
    }

    /// Preview what would be synced
    func previewSync(skill: SkillRecord, direction: SyncDirection) -> SyncPreview {
        let sourcePath: String?
        let targetPath: String?
        let targetDir: String

        switch direction {
        case .codexToClaude:
            sourcePath = skill.codexPath
            targetPath = skill.claudePath
            targetDir = AppSettings.default.claudeSkillsPath
        case .claudeToCodex:
            sourcePath = skill.claudePath
            targetPath = skill.codexPath
            targetDir = AppSettings.default.codexSkillsPath
        }

        let targetDirURL = URL(fileURLWithPath: targetDir)
        let proposedPath = targetDirURL.appendingPathComponent(skill.name).path

        let changes: [String]
        if let tPath = targetPath, FileManager.default.fileExists(atPath: tPath) {
            changes = ["Overwrite existing skill at: \(tPath)"]
        } else {
            changes = ["Create new skill at: \(proposedPath)"]
        }

        return SyncPreview(
            skillName: skill.name,
            direction: direction,
            sourcePath: sourcePath ?? "N/A",
            targetPath: proposedPath,
            changes: changes,
            fileCount: skill.directoryStructure?.fileCount ?? 0,
            warnings: skill.healthWarnings
        )
    }

    /// Execute sync
    func sync(skill: SkillRecord, direction: SyncDirection, mode: SyncMode) async throws -> SyncResult {
        let fm = FileManager.default

        let sourcePath: String?
        let targetDir: String

        switch direction {
        case .codexToClaude:
            sourcePath = skill.codexPath
            targetDir = AppSettings.default.claudeSkillsPath
        case .claudeToCodex:
            sourcePath = skill.claudePath
            targetDir = AppSettings.default.codexSkillsPath
        }

        guard let sPath = sourcePath, fm.fileExists(atPath: sPath) else {
            throw SyncError.sourceNotFound(skill.name)
        }

        let targetURL = URL(fileURLWithPath: targetDir).appendingPathComponent(skill.name)
        let targetPath = targetURL.path

        // Create backup if target exists
        if fm.fileExists(atPath: targetPath) {
            let existingPaths = [targetPath]
            _ = try await backupService.createBackup(
                skillName: skill.name,
                paths: existingPaths,
                operationType: "sync_overwrite"
            )
            try fm.removeItem(atPath: targetPath)
        }

        // Ensure target parent directory exists
        try fm.createDirectory(at: URL(fileURLWithPath: targetDir),
                               withIntermediateDirectories: true)

        switch mode {
        case .copy:
            do {
                try fm.copyItem(atPath: sPath, toPath: targetPath)
            } catch {
                throw SyncError.copyFailed(error.localizedDescription)
            }
        case .symlink:
            do {
                try fm.createSymbolicLink(atPath: targetPath, withDestinationPath: sPath)
            } catch {
                throw SyncError.symlinkCreationFailed(error.localizedDescription)
            }
        }

        return SyncResult(
            skillName: skill.name,
            direction: direction,
            mode: mode,
            targetPath: targetPath,
            success: true
        )
    }

    /// Batch sync multiple skills
    func batchSync(
        skills: [SkillRecord],
        direction: SyncDirection,
        mode: SyncMode,
        progressHandler: ((String, Bool) -> Void)? = nil
    ) async throws -> [SyncResult] {
        var results: [SyncResult] = []

        for skill in skills {
            do {
                let result = try await sync(skill: skill, direction: direction, mode: mode)
                results.append(result)
                progressHandler?(skill.name, true)
            } catch {
                results.append(SyncResult(
                    skillName: skill.name,
                    direction: direction,
                    mode: mode,
                    targetPath: "",
                    success: false,
                    errorMessage: error.localizedDescription
                ))
                progressHandler?(skill.name, false)
            }
        }

        return results
    }
}

// MARK: - Sync Preview
struct SyncPreview: Sendable {
    let skillName: String
    let direction: SyncDirection
    let sourcePath: String
    let targetPath: String
    let changes: [String]
    let fileCount: Int
    let warnings: [String]

    var summary: String {
        "\(direction.rawValue): \(changes.count) change(s), \(fileCount) file(s)"
    }
}

// MARK: - Sync Result
struct SyncResult: Identifiable, Sendable {
    var id: String { "\(skillName)_\(direction.rawValue)_\(Date().timeIntervalSince1970)" }
    let skillName: String
    let direction: SyncDirection
    let mode: SyncMode
    let targetPath: String
    let success: Bool
    let errorMessage: String?
    let timestamp: Date = Date()

    init(skillName: String, direction: SyncDirection, mode: SyncMode, targetPath: String, success: Bool, errorMessage: String? = nil) {
        self.skillName = skillName
        self.direction = direction
        self.mode = mode
        self.targetPath = targetPath
        self.success = success
        self.errorMessage = errorMessage
    }
}
