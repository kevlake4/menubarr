import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var vm: SessionsViewModel
    @Environment(\.dismiss) private var dismiss

    // Plex
    @AppStorage("plex.baseURL") private var baseURL: String = "http://YOUR_PLEX_HOST:32400"
    @AppStorage("plex.token")   private var token: String   = "YOUR_PLEX_TOKEN_HERE"

    // Tautulli
    @AppStorage("tautulli.baseURL") private var tautulliBaseURL: String = "http://192.168.0.43:8181"
    @AppStorage("tautulli.apiKey")  private var tautulliKey: String     = "f21621fbc0e349d68876928e2b9807e3"

    // Notifications
    @AppStorage("notifications.enabled")      private var notificationsEnabled: Bool = true
    @AppStorage("notifications.allowPlaying") private var allowPlaying: Bool = true
    @AppStorage("notifications.allowPaused")  private var allowPaused: Bool  = true
    @AppStorage("notifications.minInterval")  private var minInterval: Double = 60

    var body: some View {
        Form {
            // MARK: Plex Server
            Section(header: Text("Plex Server")) {
                baseURLField
                SecureField("Plex Token", text: $token)
                HStack {
                    Spacer()
                    Button("Save Plex") {
                        PlexAPI.shared.baseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
                        PlexAPI.shared.token   = token.trimmingCharacters(in: .whitespacesAndNewlines)
                        Task { await vm.refresh() }
                        dismiss()
                    }
                    .keyboardShortcut(.return, modifiers: [.command])
                }
            }

            // MARK: Tautulli
            Section(header: Text("Tautulli")) {
                tautulliBaseURLField
                SecureField("API Key", text: $tautulliKey)
                HStack {
                    Spacer()
                    Button("Save Tautulli") {
                        TautulliAPI.shared.baseURL = tautulliBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
                        TautulliAPI.shared.apiKey  = tautulliKey.trimmingCharacters(in: .whitespacesAndNewlines)
                        Task { await vm.refresh() }
                        dismiss()
                    }
                }
            }

            // MARK: Notifications
            Section(header: Text("Notifications")) {
                Toggle("Enable notifications", isOn: $notificationsEnabled)
                    .onChange(of: notificationsEnabled) {   // ✅ new API
                        if notificationsEnabled {
                            NotificationManager.shared.configure()
                        }
                    }

                Toggle("Notify on Playing", isOn: $allowPlaying)
                Toggle("Notify on Paused",  isOn: $allowPaused)

                HStack {
                    Text("Cooldown")
                    Spacer()
                    Slider(value: $minInterval, in: 5...600, step: 5)
                        .frame(width: 180)
                    Text("\(Int(minInterval))s")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                Button {
                    NotificationManager.shared.sendTest()
                } label: {
                    Label("Send Test Notification", systemImage: "bell.badge")
                }
                .buttonStyle(.bordered)
            }

            // MARK: Networking / ATS hint
            Section(header: Text("Networking")) {
                Text("""
If your servers use HTTP on a LAN, add an ATS exception in Info.plist so the app can connect.

<key>NSAppTransportSecurity</key>
<dict>
  <key>NSExceptionDomains</key>
  <dict>
    <key>192.168.0.43</key> <!-- Tautulli -->
    <dict>
      <key>NSExceptionAllowsInsecureHTTPLoads</key><true/>
      <key>NSIncludesSubdomains</key><true/>
    </dict>
    <key>YOUR_PLEX_HOST</key> <!-- Plex -->
    <dict>
      <key>NSExceptionAllowsInsecureHTTPLoads</key><true/>
      <key>NSIncludesSubdomains</key><true/>
    </dict>
  </dict>
</dict>
""")
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(.secondary)
            }
        }
        .padding()
        .onAppear {
            PlexAPI.shared.baseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            PlexAPI.shared.token   = token.trimmingCharacters(in: .whitespacesAndNewlines)
            TautulliAPI.shared.baseURL = tautulliBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            TautulliAPI.shared.apiKey  = tautulliKey.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    // MARK: - Helpers for macOS 13 compatibility
    @ViewBuilder
    private var baseURLField: some View {
        if #available(macOS 14.0, *) {
            TextField("Base URL (e.g. http://192.168.1.10:32400)", text: $baseURL).textContentType(.URL)
        } else {
            TextField("Base URL (e.g. http://192.168.1.10:32400)", text: $baseURL)
        }
    }

    @ViewBuilder
    private var tautulliBaseURLField: some View {
        if #available(macOS 14.0, *) {
            TextField("Tautulli Base URL (e.g. http://192.168.0.43:8181)", text: $tautulliBaseURL).textContentType(.URL)
        } else {
            TextField("Tautulli Base URL (e.g. http://192.168.0.43:8181)", text: $tautulliBaseURL)
        }
    }
}
