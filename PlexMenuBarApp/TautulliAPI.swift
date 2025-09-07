//
//  TautulliItem.swift
//  PlexMenuBarApp
//
//  Created by Kevin Lake on 06/09/2025.
//


import Foundation

struct TautulliItem: Identifiable {
    let id = UUID()
    let title: String
    let user: String?
    let mediaType: String?
    let date: Date?
    let status: String?
}

enum TautulliError: Error, LocalizedError {
    case notConfigured, badURL, httpStatus(Int), decode(String)
    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Set your Tautulli base URL and API key in Settings."
        case .badURL:        return "Invalid Tautulli base URL."
        case .httpStatus(let c): return "Tautulli returned HTTP \(c)."
        case .decode(let why):  return "Could not parse Tautulli history (\(why))."
        }
    }
}

final class TautulliAPI {
    static let shared = TautulliAPI()

    // Defaults set to what you used in curl; change in Settings any time
    var baseURL: String {
        get { UserDefaults.standard.string(forKey: "tautulli.baseURL") ?? "http://192.168.0.43:8181" }
        set { UserDefaults.standard.set(newValue, forKey: "tautulli.baseURL") }
    }
    var apiKey: String {
        get { UserDefaults.standard.string(forKey: "tautulli.apiKey") ?? "f21621fbc0e349d68876928e2b9807e3" }
        set { UserDefaults.standard.set(newValue, forKey: "tautulli.apiKey") }
    }

    /// Fetch last `count` history items from Tautulli (`cmd=get_history`)
    /// Accepts common Tautulli shapes:
    /// { "response": { "data": { "records": [ ... ] } } }
    /// { "response": { "data": { "data":    [ ... ] } } } (older)
    /// { "response": { "data": [ ... ] } }
    func fetchHistory(count: Int = 5) async throws -> [TautulliItem] {
        let base = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let key  = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !base.isEmpty, !key.isEmpty else { throw TautulliError.notConfigured }

        guard var comps = URLComponents(string: "\(base)/api/v2") else { throw TautulliError.badURL }
        comps.queryItems = [
            URLQueryItem(name: "apikey", value: key),
            URLQueryItem(name: "cmd",    value: "get_history"),
            URLQueryItem(name: "count",  value: String(count))
        ]
        guard let url = comps.url else { throw TautulliError.badURL }

        let (data, resp) = try await URLSession.shared.data(from: url)
        guard let http = resp as? HTTPURLResponse else { throw TautulliError.httpStatus(-1) }
        guard (200..<300).contains(http.statusCode) else { throw TautulliError.httpStatus(http.statusCode) }

        // Parse flexibly
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TautulliError.decode("top-level not an object")
        }
        let response = (root["response"] as? [String: Any]) ?? root
        let dataObj  = (response["data"] as? [String: Any]) ?? [:]

        // Try records/data arrays
        let rawArray =
            (dataObj["records"] as? [[String: Any]]) ??
            (dataObj["data"]    as? [[String: Any]]) ??
            (response["data"]   as? [[String: Any]]) // some builds
        guard let arr = rawArray, !arr.isEmpty else {
            let keys1 = Array(root.keys)
            let keys2 = Array(response.keys)
            let keys3 = Array(dataObj.keys)
            let preview = String(data: data.prefix(400), encoding: .utf8) ?? "<non-utf8>"
            throw TautulliError.decode("no records/data array. keys root=\(keys1) response=\(keys2) data=\(keys3) preview=\(preview)")
        }

        if let first = arr.first { print("📚 Tautulli first item keys:", Array(first.keys)) }

        let items: [TautulliItem] = arr.compactMap { r in
            // Build a human-readable title
            let mtype = (r["media_type"] as? String) ?? (r["type"] as? String)
            let user  = (r["user"] as? String) ?? (r["friendly_name"] as? String) ?? (r["username"] as? String)

            // Episode formatting if fields exist
            let gp = (r["grandparent_title"] as? String) ?? (r["series_title"] as? String)
            let parentIdx = (r["parent_index"] as? Int) ?? (r["season"] as? Int)
            let idx = (r["index"] as? Int) ?? (r["episode"] as? Int)
            let epTitle = (r["title"] as? String) ?? (r["episode_title"] as? String)
            let movieTitle = (r["full_title"] as? String) ?? (r["title"] as? String) ?? (r["search_title"] as? String)
            let year = (r["year"] as? Int)

            let builtTitle: String = {
                if (mtype ?? "").lowercased() == "episode", (gp != nil || epTitle != nil) {
                    let s = parentIdx.map { "S\($0)" } ?? ""
                    let e = idx.map { "E\($0)" } ?? ""
                    let se = (s.isEmpty && e.isEmpty) ? "" : " • \(s)\(e)"
                    let ep = epTitle ?? ""
                    return [gp ?? "", se, ep].filter { !$0.isEmpty }.joined(separator: " • ")
                } else {
                    let yr = year.map { " (\($0))" } ?? ""
                    return (movieTitle ?? "Unknown") + yr
                }
            }()

            // Action/status
            let status: String? =
                (r["action"] as? String) ??
                ((r["watched_status"] as? Int).map { $0 == 1 ? "Watched" : "Unwatched" }) ??
                (r["event_type"] as? String)

            // Timestamps: Tautulli often uses epoch seconds for 'date', 'started', 'stopped'
            let date: Date? = {
                if let t = r["date"] as? TimeInterval { return Date(timeIntervalSince1970: t) }
                if let t = r["started"] as? TimeInterval { return Date(timeIntervalSince1970: t) }
                if let t = r["stopped"] as? TimeInterval { return Date(timeIntervalSince1970: t) }
                if let s = r["date"] as? String, let dbl = Double(s) { return Date(timeIntervalSince1970: dbl) }
                return nil
            }()

            return TautulliItem(title: builtTitle, user: user, mediaType: mtype, date: date, status: status)
        }

        // Tautulli usually returns newest first; keep order and cap to count
        return Array(items.prefix(count))
    }
}