import SwiftUI

struct MenuContentView: View {
    // Display options
    @AppStorage("display.showNowPlaying") private var showNowPlaying: Bool = true
    @AppStorage("display.showHistory") private var showHistory: Bool = true

    @EnvironmentObject var vm: SessionsViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            // --- Plex Now Playing ---
            if showNowPlaying {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Plex Now Playing")
                        .font(.headline)

                    if let msg = vm.errorMessage {
                        Box { Text("⚠️  \(msg)") }
                    } else if vm.isLoading && vm.sessions.isEmpty {
                        Box { ProgressView("Loading Now Playing…") }
                    } else if vm.sessions.isEmpty {
                        Box { Text("No one is playing anything right now.") }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(vm.sessions.enumerated()), id: \.offset) { _, item in
                                SessionRow(metadata: item)
                                    .padding(8)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(.windowBackgroundColor)))
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary.opacity(0.25)))
                            }
                        }
                        .padding(.top, 2)
                    }
                }
            }

            // --- Tautulli Recent History (last 5) ---
            if showHistory {
                if let msg = vm.tautulliError {
                    Box { Text("📚 History: \(msg)") }
                } else if vm.isLoading && vm.tautulliItems.isEmpty {
                    Box { ProgressView("Loading Recent History…") }
                } else if !vm.tautulliItems.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Recent History")
                                .font(.headline)
                            Spacer()
                            Text(vm.tautulliItems.count == 1 ? "1 item" : "\(vm.tautulliItems.count) items")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        ForEach(vm.tautulliItems) { h in
                            HistoryRow(item: h)
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color(.windowBackgroundColor)))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary.opacity(0.25)))
                        }
                    }
                    .padding(.top, 2)
                }
            }

            footer
        }
        .padding(12)
        .frame(minWidth: 340)
        .task {
            await vm.refresh()
        }
    }

    // MARK: - Header / Footer

    private var header: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading) {
                Text("menubarr")
                    .font(.headline)
                if let ts = vm.lastUpdated {
                    Text("Updated \(ts.formatted(date: .omitted, time: .standard))")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }

    private var footer: some View {
        VStack(spacing: 6) {
            Divider()
            HStack {
                Button {
                    Task { await vm.refresh(force: true) }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)

                Spacer()

                Button {
                    openWindow(id: "settings")
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                .buttonStyle(.bordered)

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("Quit", systemImage: "power")
                }
                .buttonStyle(.bordered)
            }

            HStack {
                Spacer()
                Text("menubarr v0.2.0")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 6)
    }
}

// MARK: - Rows

private struct SessionRow: View {
    let metadata: Metadata
    var titleText: String {
        if let type = metadata.type?.lowercased(), type == "episode" {
            let show = metadata.grandparentTitle ?? ""
            let season = metadata.parentIndex.map { "S\($0)" } ?? ""
            let ep = metadata.index.map { "E\($0)" } ?? ""
            let epTitle = metadata.title ?? ""
            return [show, [season, ep].joined(), epTitle].filter { !$0.isEmpty }.joined(separator: " • ")
        } else {
            return [metadata.title ?? "", metadata.year.map(String.init) ?? ""].filter { !$0.isEmpty }.joined(separator: " • ")
        }
    }
    var userText: String {
        let user = metadata.User?.title ?? "Unknown user"
        let dev = metadata.Player?.title ?? metadata.Player?.product ?? "Device"
        return "\(user) on \(dev)"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "play.rectangle.fill")
                .imageScale(.large)
            VStack(alignment: .leading, spacing: 2) {
                Text(titleText).font(.subheadline).bold()
                Text(userText).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

private struct HistoryRow: View {
    let item: TautulliItem

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "clock")
                .imageScale(.large)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).font(.subheadline).bold()
                HStack(spacing: 6) {
                    if let u = item.user { Text(u) }
                    if let mt = item.mediaType { Text("• \(mt)") }
                    if let d = item.date {
                        Text("• \(d.formatted(date: .abbreviated, time: .shortened))")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

// MARK: - Utility container

private struct Box<Content: View>: View {
    @ViewBuilder let content: () -> Content
    var body: some View {
        content()
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .windowBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.secondary.opacity(0.35), lineWidth: 1)
            )
    }
}
