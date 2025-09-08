import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var vm: SessionsViewModel
    @Environment(\.dismiss) private var dismiss

    // Plex
    @AppStorage("plex.baseURL") private var baseURL: String = "http://YOUR_PLEX_HOST:32400"
    @AppStorage("plex.token")   private var token: String   = "YOUR_PLEX_TOKEN_HERE"

    // Tautulli
    @AppStorage("tautulli.baseURL") private var tautulliBaseURL: String = "http://192.168.0.43:8181"
    @AppStorage("tautulli.apiKey")  private var tautulliKey: String     = "YOUR_TAUTULLI_API_KEY"

    // Notifications
    @AppStorage("notifications.enabled")      private var notificationsEnabled: Bool = true
    @AppStorage("notifications.allowPlaying") private var allowPlaying: Bool  = true
    @AppStorage("notifications.allowPaused")  private var allowPaused: Bool   = true
    @AppStorage("notifications.minInterval")  private var minInterval: Double = 60

    // Display
    @AppStorage("display.showNowPlaying") private var showNowPlaying: Bool = true
    @AppStorage("display.showHistory")    private var showHistory: Bool    = true

    var body: some View {
        VStack(spacing: 0) {
            Form {
                // MARK: Plex
                Section(header: Text("Plex")) {
                    plexBaseURLField
                    SecureField("Plex Token", text: $token)
                        .textContentType(.password)
                    HStack {
                        Spacer()
                        Button("Test Plex Connection") { Task { await vm.testPlex() } }
                            .buttonStyle(.borderedProminent)
                    }
                }

                // MARK: Tautulli
                Section(header: Text("Tautulli")) {
                    tautulliBaseURLField
                    SecureField("Tautulli API Key", text: $tautulliKey)
                        .textContentType(.password)
                    HStack {
                        Spacer()
                        Button("Test Tautulli Connection") { Task { await vm.testTautulli() } }
                            .buttonStyle(.borderedProminent)
                    }
                }

                // MARK: Notifications
                Section(header: Text("Notifications")) {
                    Toggle("Enable notifications", isOn: $notificationsEnabled)
                    Toggle("Notify while playing", isOn: $allowPlaying)
                    Toggle("Notify when paused", isOn: $allowPaused)
                    HStack {
                        Text("Minimum interval")
                        Spacer()
                        Slider(value: $minInterval, in: 10...600, step: 10) {
                            Text("Minimum interval")
                        } minimumValueLabel: { Text("10s") } maximumValueLabel: { Text("10m") }
                    }
                    Text("Won’t notify the same session more often than this.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                // MARK: Display
                Section(header: Text("Display")) {
                    Toggle("Show Now Playing section", isOn: $showNowPlaying)
                    Toggle("Show Recent History section", isOn: $showHistory)
                }

                // MARK: Networking hint
                Section(header: Text("Networking")) {
                    Text("""
If your Plex or Tautulli hosts are on a local network, ensure the base URLs are reachable from this Mac. \
If you use HTTPS with a self-signed certificate, you may need to allow it in Keychain Access.
""")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack {
                Button("Close") { dismiss() }
                Spacer()
                Button {
                    Task {
                        await vm.refresh(force: true)
                        dismiss()
                    }
                } label: {
                    Label("Save & Refresh", systemImage: "arrow.clockwise")
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding(12)
        }
        .frame(width: 520, height: 640)
    }

    // MARK: - Fields

    @ViewBuilder
    private var plexBaseURLField: some View {
        if #available(macOS 14.0, *) {
            TextField("Plex Base URL (e.g. http://192.168.1.10:32400)", text: $baseURL)
                .textContentType(.URL)
        } else {
            TextField("Plex Base URL (e.g. http://192.168.1.10:32400)", text: $baseURL)
        }
    }

    @ViewBuilder
    private var tautulliBaseURLField: some View {
        if #available(macOS 14.0, *) {
            TextField("Tautulli Base URL (e.g. http://192.168.0.43:8181)", text: $tautulliBaseURL)
                .textContentType(.URL)
        } else {
            TextField("Tautulli Base URL (e.g. http://192.168.0.43:8181)", text: $tautulliBaseURL)
        }
    }
}
