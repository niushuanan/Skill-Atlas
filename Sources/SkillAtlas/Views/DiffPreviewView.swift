import SwiftUI

struct DiffPreviewView: View {
    @Environment(AppController.self) private var controller
    let skill: SkillRecord
    @State private var showCodexContent = true

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.title2)
                Text("Diff Preview: \(skill.name)")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()

                // Toggle
                Picker("View", selection: $showCodexContent) {
                    Text("Codex").tag(true)
                    Text("Claude").tag(false)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)

                Button("Close") {
                    controller.selectedSkill = nil
                }
                .padding(.leading, 8)
            }
            .padding()

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Overview
                    GroupBox("Overview") {
                        VStack(alignment: .leading, spacing: 8) {
                            DiffRow(label: "Status", value: skill.syncStatus.rawValue)
                            DiffRow(label: "Codex Hash", value: skill.codexHash ?? "N/A")
                            DiffRow(label: "Claude Hash", value: skill.claudeHash ?? "N/A")
                            DiffRow(label: "Codex Path", value: skill.codexPath ?? "N/A")
                            DiffRow(label: "Claude Path", value: skill.claudePath ?? "N/A")

                            if skill.codexMtime != nil || skill.claudeMtime != nil {
                                Divider()
                                DiffRow(label: "Codex Modified", value: skill.codexMtime?.formatted() ?? "N/A")
                                DiffRow(label: "Claude Modified", value: skill.claudeMtime?.formatted() ?? "N/A")
                            }
                        }
                        .padding(8)
                    }

                    // Side viewer
                    GroupBox(showCodexContent ? "Codex Version" : "Claude Version") {
                        VStack(alignment: .leading, spacing: 8) {
                            let path = showCodexContent ? skill.codexPath : skill.claudePath
                            let exists = showCodexContent ? skill.codexExists : skill.claudeExists

                            if exists, let p = path {
                                if let content = try? String(contentsOfFile: (p as NSString).appendingPathComponent("SKILL.md"), encoding: .utf8) {
                                    ScrollView([.horizontal, .vertical]) {
                                        Text(content)
                                            .font(.system(.caption, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .frame(height: 200)
                                    .background(Color(nsColor: .textBackgroundColor).opacity(0.3))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                } else {
                                    Text("SKILL.md not found or unreadable")
                                        .foregroundStyle(.secondary)
                                        .italic()
                                }

                                // File listing
                                if let files = try? FileManager.default.contentsOfDirectory(atPath: p) {
                                    let filtered = files.filter { !$0.hasPrefix(".") }
                                    if !filtered.isEmpty {
                                        Text("Files (\(filtered.count)):")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .padding(.top, 4)
                                        ForEach(filtered, id: \.self) { file in
                                            Text("  📄 \(file)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            } else {
                                Text("Not available on this side")
                                    .foregroundStyle(.secondary)
                                    .italic()
                            }
                        }
                        .padding(8)
                    }
                }
                .padding()
            }
        }
        .frame(width: 520, height: 500)
    }
}

// MARK: - Diff Row
struct DiffRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label + ":")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .trailing)
            Text(value)
                .font(.caption)
                .foregroundStyle(.primary)
            Spacer()
        }
    }
}
