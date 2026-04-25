import SwiftUI

struct ContentView: View {
    @Environment(AppController.self) private var controller
    @State private var selectedFilter = DashboardSidebar.FilterCategory.all
    @State private var selectedSkillName: String?
    @State private var showDiscover = false
    @State private var showBackups = false
    @State private var showSettings = false

    var body: some View {
        NavigationSplitView {
            DashboardSidebar(
                selectedFilter: $selectedFilter,
                selectedSkillName: $selectedSkillName
            )
        } detail: {
            DashboardDetail(selectedSkillName: selectedSkillName)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItemGroup {
                Button(action: { Task { await controller.scan() } }) {
                    if controller.isScanning {
                        ProgressView().progressViewStyle(.circular).scaleEffect(0.5)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(controller.isScanning)
                .help("Scan skills")

                Button(action: { showDiscover = true }) {
                    Image(systemName: "magnifyingglass")
                }
                .help("Discover skills")

                Button(action: { showBackups = true }) {
                    Image(systemName: "clock.arrow.circlepath")
                }
                .help("View backups")

                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape")
                }
                .help("Settings")
            }
        }
        .sheet(isPresented: $showDiscover) {
            DiscoverView()
                .environment(controller)
                .frame(minWidth: 500, minHeight: 400)
        }
        .sheet(isPresented: $showBackups) {
            BackupsView()
                .environment(controller)
                .frame(minWidth: 500, minHeight: 400)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environment(controller)
                .frame(minWidth: 500, minHeight: 400)
        }
        .overlay(alignment: .bottom) {
            if let toast = controller.toastMessage {
                Text(toast)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        Task { try? await Task.sleep(nanoseconds: 3_000_000_000)
                            withAnimation { controller.toastMessage = nil } }
                    }
            }
        }
        .overlay(alignment: .center) {
            if let error = controller.errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill").font(.largeTitle).foregroundColor(.yellow)
                    Text(error).multilineTextAlignment(.center)
                    Button("Dismiss") { controller.errorMessage = nil }
                }
                .padding().background(.ultraThickMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12)).shadow(radius: 10)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: controller.toastMessage != nil)
    }
}
