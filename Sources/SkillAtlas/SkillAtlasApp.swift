import SwiftUI

@main
struct SkillAtlasApp: App {
    @State private var controller = AppController()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(controller)
                .frame(minWidth: 1000, minHeight: 650)
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentMinSize)
    }
}
