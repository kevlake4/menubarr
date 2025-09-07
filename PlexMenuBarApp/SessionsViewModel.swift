import Foundation
import Combine
import SwiftUI

@MainActor
final class SessionsViewModel: ObservableObject {
    @Published var sessions: [Metadata] = []
    @Published var errorMessage: String?
    @Published var lastUpdated: Date?
    @Published var isLoading = false

    // Notifications
    private var timerCancellable: AnyCancellable?
    private var previousStates: [String: String] = [:] // id -> state
    private var previousSet: Set<String> = []
    private var lastNotificationAt: [String: Date] = [:]

    // Notification prefs
    private var notificationsEnabled: Bool { UserDefaults.standard.bool(forKey: "notifications.enabled") }
    private var allowPlaying: Bool { UserDefaults.standard.object(forKey: "notifications.allowPlaying") as? Bool ?? true }
    private var allowPaused:  Bool { UserDefaults.standard.object(forKey: "notifications.allowPaused")  as? Bool ?? true }
    private var minNotifyInterval: TimeInterval {
        let v = UserDefaults.standard.double(forKey: "notifications.minInterval")
        return v > 0 ? v : 60
    }

    // Tautulli history
    @Published var tautulliItems: [TautulliItem] = []
    @Published var tautulliError: String?

    init() {
        let d = UserDefaults.standard
        if d.object(forKey: "notifications.enabled") == nil { d.set(true, forKey: "notifications.enabled") }
        if d.object(forKey: "notifications.allowPlaying") == nil { d.set(true, forKey: "notifications.allowPlaying") }
        if d.object(forKey: "notifications.allowPaused")  == nil { d.set(true, forKey: "notifications.allowPaused") }
        if d.object(forKey: "notifications.minInterval")  == nil { d.set(60.0, forKey: "notifications.minInterval") }

        startTimer()
        Task { await refresh() }
    }

    func startTimer() {
        timerCancellable = Timer.publish(every: 600, on: .main, in: .common)
            .autoconnect()
            .prepend(Date())
            .sink { [weak self] _ in
                Task { await self?.refresh() }
            }
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        // Fetch Plex (for Now Playing) and Tautulli (for history)
        do {
            let data = try await PlexAPI.shared.fetchSessions()
            errorMessage = nil
            lastUpdated = Date()

            let current = data
            let currentMap = Dictionary(uniqueKeysWithValues: current.map { (stableID(for: $0), $0) })
            let currentSet = Set(currentMap.keys)

            // New sessions
            for id in currentSet.subtracting(previousSet) {
                if let item = currentMap[id] {
                    let state = normalizedState(item.Player?.state)
                    if shouldNotifyNew(forState: state), notifyThrottle(key: "new:\(id)") {
                        NotificationManager.shared.send(
                            title: "Now Playing",
                            body: summaryLine(for: item, includeState: true)
                        )
                    }
                }
            }

            // State changes
            for (id, item) in currentMap {
                let newState = normalizedState(item.Player?.state)
                if let prevState = previousStates[id], prevState != newState,
                   shouldNotifyChange(toState: newState),
                   notifyThrottle(key: "state:\(id):\(newState)") {
                    NotificationManager.shared.send(
                        title: "Playback changed",
                        body: "\(title(for: item)) • \(item.User?.title ?? "Someone"): \(pretty(prevState)) → \(pretty(newState))"
                    )
                }
            }

            // Update trackers + publish
            sessions = current
            previousSet = currentSet
            previousStates = currentMap.mapValues { normalizedState($0.Player?.state) }

        } catch {
            sessions = []
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            lastUpdated = Date()
        }

        // Tautulli history (independent)
        do {
            let hist = try await TautulliAPI.shared.fetchHistory(count: 5)
            tautulliItems = hist
            tautulliError = nil
        } catch {
            tautulliItems = []
            tautulliError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    // MARK: - Helpers

    func title(for item: Metadata) -> String {
        switch (item.type ?? "").lowercased() {
        case "episode":
            let show = item.grandparentTitle ?? "Unknown show"
            let s = item.parentIndex.map { "S\($0)" } ?? ""
            let e = item.index.map { "E\($0)" } ?? ""
            let se = (s.isEmpty && e.isEmpty) ? "" : " • \(s)\(e)"
            let ep = item.title ?? "Episode"
            return "\(show)\(se) • \(ep)"
        case "track":
            let artist = item.grandparentTitle ?? ""
            let album = item.parentTitle ?? ""
            let track = item.title ?? "Track"
            return [artist, album, track].filter { !$0.isEmpty }.joined(separator: " • ")
        default:
            let t = item.title ?? "Title"
            let yr = item.year.map { " (\($0))" } ?? ""
            return t + yr
        }
    }

    private func summaryLine(for item: Metadata, includeState: Bool = false) -> String {
        let t = title(for: item)
        let who = item.User?.title ?? "Someone"
        let dev = item.Player?.title ?? item.Player?.product ?? "device"
        let state = (item.Player?.state?.capitalized).map { " • \($0)" } ?? ""
        return includeState ? "\(t) • \(who) on \(dev)\(state)" : "\(t) • \(who) on \(dev)"
    }

    private func normalizedState(_ s: String?) -> String {
        (s ?? "unknown").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
    private func pretty(_ state: String) -> String { state.capitalized }

    private func shouldNotifyNew(forState state: String) -> Bool {
        guard notificationsEnabled else { return false }
        switch state {
        case "playing": return allowPlaying
        case "paused":  return allowPaused
        default:        return false
        }
    }
    private func shouldNotifyChange(toState state: String) -> Bool {
        shouldNotifyNew(forState: state)
    }

    private func notifyThrottle(key: String) -> Bool {
        let now = Date()
        if let last = lastNotificationAt[key], now.timeIntervalSince(last) < minNotifyInterval {
            return false
        }
        lastNotificationAt[key] = now
        return true
    }

    private func stableID(for item: Metadata) -> String {
        if let rk = item.ratingKey, !rk.isEmpty { return "rk:\(rk)" }
        if let sk = item.sessionKey, !sk.isEmpty { return "sk:\(sk)" }
        let user = item.User?.title ?? "user"
        let dev  = item.Player?.title ?? item.Player?.product ?? "device"
        let t    = title(for: item)
        return "fx:\(user)|\(dev)|\(t)"
    }
}
