import SwiftUI

struct SettingsView: View {
    @Environment(AppController.self) private var controller

    var body: some View {
        TabView {
            generalSettings
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            sourceSettings
                .tabItem {
                    Label("Sources", systemImage: "link.circle")
                }

            aboutSettings
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            ToolbarItem {
                Button("Save") {
                    Task { await controller.saveSettings() }
                }
                .buttonStyle(.borderedProminent)
            }
            ToolbarItem {
                Button("Reset Defaults") {
                    Task { await controller.resetSettings() }
                }
                .font(.caption)
            }
        }
    }

    // MARK: - General Settings
    private var generalSettings: some View {
        Form {
            Section("Skill Paths") {
                HStack {
                    Text("Codex Skills Path")
                        .frame(width: 160, alignment: .trailing)
                    TextField("Path", text: Bindable(controller).settings.codexSkillsPath)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                }

                HStack {
                    Text("Claude Skills Path")
                        .frame(width: 160, alignment: .trailing)
                    TextField("Path", text: Bindable(controller).settings.claudeSkillsPath)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                }
            }

            Section("Sync Defaults") {
                HStack {
                    Text("Default Sync Mode")
                        .frame(width: 160, alignment: .trailing)
                    Picker("", selection: Bindable(controller).settings.defaultSyncMode) {
                        ForEach(SyncMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .labelsHidden()
                }

                HStack {
                    Text("Delete Confirmation")
                        .frame(width: 160, alignment: .trailing)
                    Toggle("Require confirmation before deletion", isOn: Bindable(controller).settings.enableDeleteConfirmation)
                        .toggleStyle(.checkbox)
                }
            }

            Section("Backup") {
                HStack {
                    Text("Retention (days)")
                        .frame(width: 160, alignment: .trailing)
                    Stepper(value: Bindable(controller).settings.backupRetentionDays, in: 1...365) {
                        Text("\(controller.settings.backupRetentionDays) days")
                    }
                }

                HStack {
                    Spacer()
                    Button("Show Backup Directory in Finder") {
                        let path = AppSettings.default.backupRoot.path
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
                    }
                    .font(.caption)
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Source Settings
    private var sourceSettings: some View {
        VStack {
            List {
                ForEach(Array(Bindable(controller).settings.sources)) { $source in
                    HStack {
                        Toggle("", isOn: $source.enabled)
                            .toggleStyle(.checkbox)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(source.name)
                                .font(.body)
                                .fontWeight(.medium)
                            Text(source.url)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(source.type.rawValue)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }

                        Spacer()

                        Text("Priority: \(source.priority)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.inset)

            HStack {
                Spacer()
                Text("Add new sources coming in V1.5")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
            }
        }
    }

    // MARK: - About
    private var aboutSettings: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "puzzlepiece.extension.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            Text("Skill Atlas")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Version 1.0.0")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Unified Skill Manager for Codex & Claude Code")
                .font(.body)
                .foregroundStyle(.secondary)

            Divider()
                .frame(width: 200)

            VStack(alignment: .leading, spacing: 8) {
                Label("Manage skills across Codex and Claude Code", systemImage: "square.grid.2x2")
                Label("Sync with safety (backup + atomic writes)", systemImage: "arrow.triangle.2.circlepath")
                Label("Discover new skills by describing what you need", systemImage: "magnifyingglass")
                Label("Delete with confidence (auto-backup + restore)", systemImage: "trash.slash")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Spacer()

            Text("Built with SwiftUI · macOS 14+")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}
