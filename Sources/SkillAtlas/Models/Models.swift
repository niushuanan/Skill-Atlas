import Foundation

// MARK: - Sync Status
enum SyncStatus: String, Codable, CaseIterable, Sendable {
    case onlyCodex = "Only Codex"
    case onlyClaude = "Only Claude"
    case consistent = "Consistent"
    case conflicted = "Conflicted"

    var colorName: String {
        switch self {
        case .onlyCodex: return "blue"
        case .onlyClaude: return "orange"
        case .consistent: return "green"
        case .conflicted: return "red"
        }
    }

    var iconName: String {
        switch self {
        case .onlyCodex: return "chevron.left.circle"
        case .onlyClaude: return "chevron.right.circle"
        case .consistent: return "checkmark.circle"
        case .conflicted: return "exclamationmark.triangle"
        }
    }
}

// MARK: - Sync Mode
enum SyncMode: String, Codable, CaseIterable, Sendable {
    case copy = "Copy"
    case symlink = "Symlink"
}

// MARK: - Sync Direction
enum SyncDirection: String, Codable, CaseIterable, Sendable {
    case codexToClaude = "Codex → Claude"
    case claudeToCodex = "Claude → Codex"
}

// MARK: - Source Type
enum SourceType: String, Codable, CaseIterable, Sendable {
    case github = "GitHub"
    case registry = "Registry"
    case local = "Local"
}

// MARK: - Directory Structure
struct DirectoryStructure: Codable, Equatable, Hashable, Sendable {
    var hasScripts: Bool = false
    var hasAssets: Bool = false
    var hasReferences: Bool = false
    var hasAgents: Bool = false
    var fileCount: Int = 0
    var subdirectoryCount: Int = 0
}

// MARK: - Skill Record
struct SkillRecord: Identifiable, Codable, Equatable, Hashable, Sendable {
    var id: String { name }
    let name: String
    var codexExists: Bool
    var claudeExists: Bool
    var codexPath: String?
    var claudePath: String?
    var codexHash: String?
    var claudeHash: String?
    var codexMtime: Date?
    var claudeMtime: Date?
    var codexSize: Int64?
    var claudeSize: Int64?
    var healthWarnings: [String]
    var description: String?
    var hasSKILLMD: Bool
    var directoryStructure: DirectoryStructure?

    var syncStatus: SyncStatus {
        if codexExists && claudeExists {
            if codexHash == claudeHash {
                return .consistent
            } else {
                return .conflicted
            }
        } else if codexExists {
            return .onlyCodex
        } else {
            return .onlyClaude
        }
    }

    var isSymlinked: Bool {
        guard let path = claudePath else { return false }
        let resolved = try? FileManager.default.destinationOfSymbolicLink(atPath: path)
        return resolved != nil
    }

    var fileCountDisplay: String {
        guard let s = directoryStructure else { return "N/A" }
        return "\(s.fileCount) files"
    }

    var healthStatus: String {
        if healthWarnings.isEmpty { return "Healthy" }
        return "\(healthWarnings.count) issue(s)"
    }

    mutating func computeHealth() {
        var warnings: [String] = []
        if !hasSKILLMD {
            warnings.append("Missing SKILL.md")
        }
        if description == nil || description?.isEmpty == true {
            warnings.append("Missing description")
        }
        if let structr = directoryStructure, structr.fileCount == 0 {
            warnings.append("Empty directory")
        }
        healthWarnings = warnings
    }
}

// MARK: - Scanned Info (intermediate)
struct ScannedInfo: Sendable {
    let name: String
    let path: String
    let hash: String
    let mtime: Date
    let size: Int64
    let description: String?
    let hasSKILLMD: Bool
    let structure: DirectoryStructure
}

// MARK: - Backup Record
struct BackupRecord: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let skillName: String
    let operationType: String
    let createdAt: Date
    let sourcePaths: [String]
    let backupDir: String
    let side: String

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: createdAt)
    }
}

// MARK: - Source Record
struct SourceRecord: Identifiable, Codable, Equatable, Sendable {
    let id: String
    var name: String
    var type: SourceType
    var url: String
    var enabled: Bool
    var priority: Int
}

// MARK: - Discover Result
struct DiscoverResult: Identifiable, Sendable {
    var id: String { "\(source)_\(name)" }
    let name: String
    let description: String
    let source: String
    let url: String
    let updatedAt: String
    let isInstalled: Bool
    var installedSide: String? // "codex", "claude", "both", nil
}

// MARK: - App Settings
struct AppSettings: Codable, Sendable {
    var codexSkillsPath: String
    var claudeSkillsPath: String
    var defaultSyncMode: SyncMode
    var enableDeleteConfirmation: Bool
    var backupRetentionDays: Int
    var sources: [SourceRecord]

    static let `default` = AppSettings(
        codexSkillsPath: FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/skills").path,
        claudeSkillsPath: FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/skills").path,
        defaultSyncMode: .copy,
        enableDeleteConfirmation: true,
        backupRetentionDays: 30,
        sources: [
            SourceRecord(id: "gh-openai", name: "openai/skills", type: .github,
                         url: "https://github.com/openai/skills", enabled: true, priority: 1),
            SourceRecord(id: "gh-anthropic", name: "anthropics/skills", type: .github,
                         url: "https://github.com/anthropics/skills", enabled: true, priority: 2),
            SourceRecord(id: "gh-vercel", name: "vercel-labs/skills", type: .github,
                         url: "https://github.com/vercel-labs/skills", enabled: true, priority: 3),
        ]
    )

    var supportDir: URL {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent("com.skillatlas.app")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    var backupRoot: URL {
        let dir = supportDir.appendingPathComponent("Backups")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    var settingsURL: URL {
        supportDir.appendingPathComponent("settings.json")
    }
}
