import SwiftUI

struct MenuContentView: View {
    @EnvironmentObject var vm: SessionsViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            // --- Plex Now Playing ---
            if let msg = vm.errorMessage {
                Box { Text("⚠️  \(msg)") }
            } else if vm.sessions.isEmpty {
                Box { Text("No one is playing anything right now.") }
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(Array(vm.sessions.enumerated()), id: \.offset) { _, item in
                            Box {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(vm.title(for: item))
                                        .font(.headline)
                                    HStack(spacing: 12) {
                                        Label(item.User?.title ?? "Unknown user", systemImage: "person")
                                        Label(item.Player?.title ?? item.Player?.product ?? "Unknown device", systemImage: "display")
                                        Label(item.Player?.state?.capitalized ?? "Unknown", systemImage: "playpause")
                                        if let lib = item.librarySectionTitle {
                                            Label(lib, systemImage: "books.vertical")
                                        }
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(maxHeight: 360)
            }

            // --- Tautulli Recent History (last 5) ---
            if let msg = vm.tautulliError {
                Box {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Recent History").font(.headline)
                        Text("⚠️ \(msg)").foregroundStyle(.secondary)
                    }
                }
            } else if !vm.tautulliItems.isEmpty {
                Box {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recent History").font(.headline)
                        ForEach(vm.tautulliItems) { item in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("•").bold()
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title).font(.subheadline)
                                    HStack(spacing: 10) {
                                        if let u = item.user { Text(u).foregroundStyle(.secondary) }
                                        if let s = item.status { Text(s).foregroundStyle(.secondary) }
                                        if let d = item.date {
                                            Text(RelativeDateTimeFormatter().localizedString(for: d, relativeTo: .now))
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .font(.caption)
                                }
                            }
                        }
                    }
                }
            }

            footer
        }
        .padding(12)
        .frame(minWidth: 340)
    }

    private var header: some View {
        HStack {
            Label("Plex Now Playing", systemImage: "play.circle")
                .font(.headline)
            Spacer()
            if vm.isLoading {
                ProgressView().controlSize(.small)
            } else if let last = vm.lastUpdated {
                Text(RelativeDateTimeFormatter().localizedString(for: last, relativeTo: .now))
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .monospacedDigit()
            }
        }
    }

    private var footer: some View {
        HStack {
            Button {
                Task { await vm.refresh() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .keyboardShortcut("r")

            Spacer()

            Button { openWindow(id: "settings") } label: {
                Label("Settings…", systemImage: "gearshape")
            }

            Button(role: .destructive) {
                NSApp.terminate(nil)
            } label: {
                Label("Quit", systemImage: "xmark.circle")
            }
        }
        .buttonStyle(.borderless)
        .font(.callout)
        .padding(.top, 2)
    }
}

struct Box<Content: View>: View {
    @ViewBuilder var content: () -> Content
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
