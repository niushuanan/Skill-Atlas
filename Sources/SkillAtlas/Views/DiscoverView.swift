import SwiftUI

struct DiscoverView: View {
    @Environment(AppController.self) private var controller
    @State private var searchQuery = ""
    @State private var isSearching = false

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .font(.title2)
                    Text("Discover Skills")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Spacer()
                }

                HStack {
                    TextField("Describe what you need... (e.g. 'PDF processing', 'browser automation')", text: $searchQuery)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { performSearch() }

                    Button("Search") {
                        performSearch()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(searchQuery.count < 2 || isSearching)
                }
            }
            .padding()

            Divider()

            // Results
            resultsList
        }
        .toolbar {
            ToolbarItem {
                if isSearching {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.7)
                }
            }
        }
    }

    private func performSearch() {
        guard searchQuery.count >= 2 else { return }
        isSearching = true
        Task {
            await controller.searchDiscover(query: searchQuery)
            isSearching = false
        }
    }

    // MARK: - Results List
    private var resultsList: some View {
        Group {
            if controller.discoverResults.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "puzzlepiece.extension")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                    Text("Search for skills by describing what you need")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Try: 'browser automation', 'document processing', 'deployment'")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
            } else {
                List(controller.discoverResults) { result in
                    DiscoverCardView(result: result)
                        .environment(controller)
                }
                .listStyle(.inset)
            }
        }
    }
}

// MARK: - Discover Card
struct DiscoverCardView: View {
    @Environment(AppController.self) private var controller
    let result: DiscoverResult

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: result.isInstalled ? "checkmark.circle.fill" : "puzzlepiece.extension")
                .font(.title2)
                .foregroundColor(result.isInstalled ? .green : .accentColor)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(result.name)
                        .font(.body)
                        .fontWeight(.semibold)

                    if result.isInstalled {
                        Text("Installed")
                            .font(.caption2)
                            .foregroundColor(.green)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.green.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }

                Text(result.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 12) {
                    Label(result.source, systemImage: "link")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    if !result.updatedAt.isEmpty {
                        Label(result.updatedAt, systemImage: "clock")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            // Install button
            if !result.isInstalled {
                Menu("Install") {
                    Button("To Codex") {
                        Task { await controller.installDiscovered(result: result, targetSide: "codex") }
                    }
                    Button("To Claude") {
                        Task { await controller.installDiscovered(result: result, targetSide: "claude") }
                    }
                    Button("To Both") {
                        Task { await controller.installDiscovered(result: result, targetSide: "both") }
                    }
                }
                .menuStyle(.borderlessButton)
                .frame(width: 60)
            } else if let side = result.installedSide {
                Text(side == "both" ? "Both sides" : side == "codex" ? "Codex" : "Claude")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}
