import SwiftUI

@main
struct PlexMenuBarApp: App {
    @StateObject private var vm = SessionsViewModel()

    init() {
        NotificationManager.shared.configure()
    }

    var body: some Scene {
        // Menu bar dropdown
        MenuBarExtra("Plex Now Playing", systemImage: "play.circle") {
            MenuContentView()
                .environmentObject(vm)
                .frame(width: 360)
        }
        .menuBarExtraStyle(.window)

        // Settings window (macOS 13+)
        WindowGroup("Settings", id: "settings") {
            SettingsView()
                .environmentObject(vm)
                .frame(width: 520, height: 440)
        }
    }
}
