import Foundation

actor ScanService {
    func scan(codexPath: String, claudePath: String) throws -> [SkillRecord] {
        let fm = FileManager.default

        let codexScanned: [String: ScannedInfo]
        let claudeScanned: [String: ScannedInfo]

        if fm.fileExists(atPath: codexPath) {
            codexScanned = try scanDirectory(at: codexPath)
        } else {
            codexScanned = [:]
        }

        if fm.fileExists(atPath: claudePath) {
            claudeScanned = try scanDirectory(at: claudePath)
        } else {
            claudeScanned = [:]
        }

        return merge(codex: codexScanned, claude: claudeScanned, codexPath: codexPath, claudePath: claudePath)
    }

    private func scanDirectory(at path: String) throws -> [String: ScannedInfo] {
        let fm = FileManager.default
        let contents = try fm.contentsOfDirectory(atPath: path)
        var result: [String: ScannedInfo] = [:]

        for item in contents {
            guard !item.hasPrefix(".") else { continue }
            let itemPath = (path as NSString).appendingPathComponent(item)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: itemPath, isDirectory: &isDir), isDir.boolValue else { continue }

            // Read SKILL.md
            let skillMDPath = (itemPath as NSString).appendingPathComponent("SKILL.md")
            let hasSKILLMD = fm.fileExists(atPath: skillMDPath)
            var description: String?
            if hasSKILLMD, let mdContent = try? String(contentsOfFile: skillMDPath, encoding: .utf8) {
                description = parseFrontmatter(from: mdContent)
            }

            // Compute hash and structure
            let hash = computeDirectoryHash(at: itemPath)
            let structure = computeDirectoryStructure(at: itemPath)

            // Attributes
            let attrs = try fm.attributesOfItem(atPath: itemPath)
            let mtime = (attrs[.modificationDate] as? Date) ?? Date()
            let size = (attrs[FileAttributeKey("NSFileSize")] as? NSNumber)?.int64Value ?? 0

            let info = ScannedInfo(
                name: item,
                path: itemPath,
                hash: hash,
                mtime: mtime,
                size: size,
                description: description,
                hasSKILLMD: hasSKILLMD,
                structure: structure
            )
            result[item] = info
        }

        return result
    }

    private func computeDirectoryStructure(at path: String) -> DirectoryStructure {
        let fm = FileManager.default
        var structr = DirectoryStructure()

        guard let enumerator = fm.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return structr }

        while let fileURL = enumerator.nextObject() as? URL {
            let isDir = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false

            if isDir {
                structr.subdirectoryCount += 1
                let dirName = fileURL.lastPathComponent
                if dirName == "scripts" { structr.hasScripts = true }
                else if dirName == "assets" { structr.hasAssets = true }
                else if dirName == "references" { structr.hasReferences = true }
                else if dirName == "agents" { structr.hasAgents = true }
            } else {
                structr.fileCount += 1
            }
        }

        return structr
    }

    private func merge(
        codex: [String: ScannedInfo],
        claude: [String: ScannedInfo],
        codexPath: String,
        claudePath: String
    ) -> [SkillRecord] {
        let allNames = Set(codex.keys).union(claude.keys)

        return allNames.sorted().map { name in
            let c = codex[name]
            let l = claude[name]

            var record = SkillRecord(
                name: name,
                codexExists: c != nil,
                claudeExists: l != nil,
                codexPath: c?.path,
                claudePath: l?.path,
                codexHash: c?.hash,
                claudeHash: l?.hash,
                codexMtime: c?.mtime,
                claudeMtime: l?.mtime,
                codexSize: c?.size,
                claudeSize: l?.size,
                healthWarnings: [],
                description: c?.description ?? l?.description,
                hasSKILLMD: c?.hasSKILLMD ?? false || l?.hasSKILLMD ?? false,
                directoryStructure: c?.structure ?? l?.structure
            )

            var warnings: [String] = []
            if !record.hasSKILLMD {
                warnings.append("Missing SKILL.md")
            }
            if c == nil && l != nil, let lPath = l?.path {
                if isSymlink(at: lPath) {
                    warnings.append("Symlink to non-existent source")
                }
            }
            if (record.description ?? "").isEmpty {
                warnings.append("Missing description")
            }
            if let structr = record.directoryStructure, structr.fileCount == 0 && structr.subdirectoryCount == 0 {
                warnings.append("Empty directory")
            }
            record.healthWarnings = warnings

            return record
        }
    }
}
