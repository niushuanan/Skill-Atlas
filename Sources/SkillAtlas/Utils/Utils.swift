import Foundation
import CryptoKit

// MARK: - Hashing
func computeDirectoryHash(at path: String) -> String {
    let fm = FileManager.default
    let baseURL = URL(fileURLWithPath: path)
    let basePath = baseURL.path

    // Use enumerator(atPath:) which returns relative paths from the scanned dir
    guard let enumerator = fm.enumerator(atPath: basePath) else { return "" }

    var files: [(path: String, mtime: Double)] = []

    while let relativePath = enumerator.nextObject() as? String {
        // Skip hidden entries
        let lastComponent = (relativePath as NSString).lastPathComponent
        if lastComponent.hasPrefix(".") { continue }

        let fullPath = (basePath as NSString).appendingPathComponent(relativePath)
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: fullPath, isDirectory: &isDir), !isDir.boolValue else { continue }
        guard let attrs = try? fm.attributesOfItem(atPath: fullPath),
              let mtime = (attrs[.modificationDate] as? Date)?.timeIntervalSince1970 else { continue }

        files.append((relativePath, mtime))
    }

    // Sort for deterministic comparison
    files.sort { $0.path < $1.path }
    let hashInput = files.map { "\($0.path):\($0.mtime)" }.joined(separator: "\n")
    return sha256(string: hashInput)
}

func sha256(string: String) -> String {
    let data = Data(string.utf8)
    let hash = SHA256.hash(data: data)
    return hash.compactMap { String(format: "%02x", $0) }.joined()
}

func sha256(data: Data) -> String {
    let hash = SHA256.hash(data: data)
    return hash.compactMap { String(format: "%02x", $0) }.joined()
}

// MARK: - Frontmatter Parser
func parseFrontmatter(from content: String) -> String? {
    let lines = content.components(separatedBy: .newlines)
    guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else { return nil }

    var inFrontmatter = false
    var readingDescription = false
    var descriptionValue = ""

    for line in lines.dropFirst() {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed == "---" {
            if inFrontmatter { break }
            inFrontmatter = true
            continue
        }
        guard inFrontmatter else { continue }

        if trimmed.hasPrefix("description:") {
            let value = trimmed.dropFirst("description:".count).trimmingCharacters(in: .whitespaces)
            if value.hasPrefix("\"") && value.hasSuffix("\"") {
                return String(value.dropFirst().dropLast())
            }
            if !value.isEmpty {
                readingDescription = true
                descriptionValue = value
            }
        } else if readingDescription {
            if trimmed.hasPrefix("\"") {
                let endTrimmed = trimmed.hasSuffix("\"") ? String(trimmed.dropLast()) : String(trimmed.dropFirst())
                descriptionValue += " " + endTrimmed
                if trimmed.hasSuffix("\"") {
                    readingDescription = false
                }
            } else {
                descriptionValue += " " + trimmed
            }
        }
    }

    return descriptionValue.isEmpty ? nil : descriptionValue
}

// MARK: - Atomic File Operations
struct AtomicFileWriter {
    static func write(data: Data, to url: URL) throws {
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent(UUID().uuidString)
        try data.write(to: tempURL, options: .atomic)
        _ = try FileManager.default.replaceItemAt(url, withItemAt: tempURL)
    }

    static func write(string: String, to url: URL) throws {
        guard let data = string.data(using: .utf8) else {
            throw AtomicWriterError.encodingFailed
        }
        try write(data: data, to: url)
    }

    enum AtomicWriterError: LocalizedError {
        case encodingFailed
        var errorDescription: String? {
            switch self {
            case .encodingFailed: return "String encoding failed"
            }
        }
    }
}

// MARK: - Safe File Removal
struct SafeFileRemover {
    static func removeItem(at url: URL, backupTo backupURL: URL) throws {
        let fm = FileManager.default
        // Ensure backup directory exists
        try fm.createDirectory(at: backupURL.deletingLastPathComponent(),
                               withIntermediateDirectories: true)
        // Copy to backup first
        if fm.fileExists(atPath: url.path) {
            try fm.copyItem(at: url, to: backupURL)
            try fm.removeItem(at: url)
        }
    }
}

// MARK: - Symlink Detection
func isSymlink(at path: String) -> Bool {
    let resolved = try? FileManager.default.destinationOfSymbolicLink(atPath: path)
    return resolved != nil
}

func resolveSymlink(at path: String) -> String? {
    return try? FileManager.default.destinationOfSymbolicLink(atPath: path)
}
