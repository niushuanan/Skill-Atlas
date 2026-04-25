import SwiftUI

struct ContentView: View {
    @Environment(AppController.self) private var controller

    var body: some View {
        TabView(selection: Bindable(controller).selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: AppController.Tab.dashboard.icon)
                }
                .tag(AppController.Tab.dashboard)

            SyncView()
                .tabItem {
                    Label("Sync", systemImage: AppController.Tab.sync.icon)
                }
                .tag(AppController.Tab.sync)

            DiscoverView()
                .tabItem {
                    Label("Discover", systemImage: AppController.Tab.discover.icon)
                }
                .tag(AppController.Tab.discover)

            BackupsView()
                .tabItem {
                    Label("Backups", systemImage: AppController.Tab.backups.icon)
                }
                .tag(AppController.Tab.backups)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: AppController.Tab.settings.icon)
                }
                .tag(AppController.Tab.settings)
        }
        .overlay(alignment: .bottom) {
            if let toast = controller.toastMessage {
                Text(toast)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        Task {
                            try? await Task.sleep(nanoseconds: 3_000_000_000)
                            withAnimation {
                                controller.toastMessage = nil
                            }
                        }
                    }
            }
        }
        .overlay(alignment: .center) {
            if let error = controller.errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.yellow)
                    Text(error)
                        .multilineTextAlignment(.center)
                    Button("Dismiss") {
                        controller.errorMessage = nil
                    }
                }
                .padding()
                .background(.ultraThickMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(radius: 10)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: controller.toastMessage != nil)
    }
}
