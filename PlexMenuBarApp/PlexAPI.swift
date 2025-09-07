import Foundation

// ======= DEFAULT CONFIGURE (can be overridden in Settings) =======
private let DEFAULT_PLEX_BASE_URL = "http://YOUR_PLEX_HOST:32400"
private let DEFAULT_PLEX_TOKEN    = "YOUR_PLEX_TOKEN_HERE"
// =================================================================

struct PlexSessions: Decodable { let MediaContainer: MediaContainer }
struct MediaContainer: Decodable { let size: Int?; let Metadata: [Metadata]? }
struct Metadata: Decodable {
    let type: String?, title: String?, grandparentTitle: String?, parentTitle: String?
    let year: Int?, Player: Player?, User: User?, index: Int?, parentIndex: Int?
    let librarySectionTitle: String?
    // IDs for stable tracking
    let ratingKey: String?
    let sessionKey: String?
}
struct Player: Decodable { let title: String?; let product: String?; let state: String? }
struct User: Decodable { let title: String? }

enum PlexError: Error, LocalizedError {
    case notConfigured, badURL, httpStatus(Int), decode, noData
    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Set your Plex base URL and token in Settings."
        case .badURL:        return "Invalid Plex base URL."
        case .httpStatus(let c): return "Plex returned HTTP \(c)."
        case .decode:        return "Could not parse Plex response (server may be returning XML)."
        case .noData:        return "No data returned from Plex."
        }
    }
}

final class PlexAPI {
    static let shared = PlexAPI()

    var baseURL: String {
        get { UserDefaults.standard.string(forKey: "plex.baseURL") ?? DEFAULT_PLEX_BASE_URL }
        set { UserDefaults.standard.set(newValue, forKey: "plex.baseURL") }
    }
    var token: String {
        get { UserDefaults.standard.string(forKey: "plex.token") ?? DEFAULT_PLEX_TOKEN }
        set { UserDefaults.standard.set(newValue, forKey: "plex.token") }
    }

    func fetchSessions() async throws -> [Metadata] {
        let base = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let tok  = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !base.isEmpty, !tok.isEmpty,
              base != DEFAULT_PLEX_BASE_URL, tok != DEFAULT_PLEX_TOKEN
        else { throw PlexError.notConfigured }

        guard var comps = URLComponents(string: "\(base)/status/sessions") else { throw PlexError.badURL }
        comps.queryItems = [URLQueryItem(name: "X-Plex-Token", value: tok)]
        guard let url = comps.url else { throw PlexError.badURL }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.addValue("application/json", forHTTPHeaderField: "Accept")
        req.addValue("PlexMenuBarApp", forHTTPHeaderField: "X-Plex-Client-Identifier")

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw PlexError.noData }
        guard (200..<300).contains(http.statusCode) else { throw PlexError.httpStatus(http.statusCode) }
        guard !data.isEmpty else { throw PlexError.noData }

        do {
            let decoded = try JSONDecoder().decode(PlexSessions.self, from: data)
            return decoded.MediaContainer.Metadata ?? []
        } catch {
            throw PlexError.decode
        }
    }
}
