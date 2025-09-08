import Foundation
import Combine
import SwiftUI

// MARK: - Error convenience
extension Error {
    var readableDescription: String {
        (self as? LocalizedError)?.errorDescription ?? self.localizedDescription
    }
}

@MainActor
final class SessionsViewModel: ObservableObject {
    // Now Playing
    @Published var sessions: [Metadata] = []
    @Published var errorMessage: String?

    // History
    @Published var tautulliItems: [TautulliItem] = []
    @Published var tautulliError: String?

    // State
    @Published var lastUpdated: Date?
    @Published var isLoading = false

    // Notifications (kept minimal here; wire to your NotificationManager if needed)
    private var timerCancellable: AnyCancellable?

    init() {
        // Sensible defaults for new keys
        let d = UserDefaults.standard
        if d.object(forKey: "display.showNowPlaying") == nil { d.set(true, forKey: "display.showNowPlaying") }
        if d.object(forKey: "display.showHistory")    == nil { d.set(true, forKey: "display.showHistory") }

        if d.object(forKey: "notifications.enabled") == nil { d.set(true, forKey: "notifications.enabled") }
        if d.object(forKey: "notifications.allowPlaying") == nil { d.set(true, forKey: "notifications.allowPlaying") }
        if d.object(forKey: "notifications.allowPaused")  == nil { d.set(true, forKey: "notifications.allowPaused") }
        if d.object(forKey: "notifications.minInterval")  == nil { d.set(60.0, forKey: "notifications.minInterval") }

        // Optional: start polling every 30s
        startPolling()
    }

    // MARK: - Public API

    func startPolling(interval: TimeInterval = 30) {
        timerCancellable?.cancel()
        timerCancellable = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.refresh() }
            }
    }

    func stopPolling() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    func refresh(force: Bool = false) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let items = try await PlexAPI.shared.fetchSessions()
            self.sessions = items
            self.errorMessage = nil
        } catch {
            self.sessions = []
            self.errorMessage = error.readableDescription
        }

        // Respect Display setting for history: skip work and clear if hidden
        if UserDefaults.standard.bool(forKey: "display.showHistory") {
            do {
                let hist = try await TautulliAPI.shared.fetchHistory(count: 5)
                self.tautulliItems = hist
                self.tautulliError = nil
            } catch {
                self.tautulliItems = []
                self.tautulliError = error.readableDescription
            }
        } else {
            self.tautulliItems = []
            self.tautulliError = nil
        }

        lastUpdated = Date()
    }

    // MARK: - Diagnostics / Tests

    func testPlex() async {
        do {
            _ = try await PlexAPI.shared.fetchSessions()
            errorMessage = nil
        } catch {
            errorMessage = "Plex test failed: " + error.readableDescription
        }
    }

    func testTautulli() async {
        do {
            _ = try await TautulliAPI.shared.fetchHistory(count: 1)
            tautulliError = nil
        } catch {
            tautulliError = "Tautulli test failed: " + error.readableDescription
        }
    }
}
