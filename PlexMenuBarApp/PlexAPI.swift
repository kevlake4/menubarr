import Foundation

// MARK: - Models

struct PlexSessionsResponse: Codable {
    let MediaContainer: MediaContainer?
}

struct MediaContainer: Codable {
    let Metadata: [Metadata]?
}

struct Metadata: Codable, Identifiable, Hashable {
    // A synthesized stable id (ratingKey or composite)
    var id: String { ratingKey ?? UUID().uuidString }

    // Common Plex fields used in the UI
    let ratingKey: String?
    let type: String?
    let title: String?
    let year: Int?

    // Episode/Series context
    let grandparentTitle: String?
    let parentIndex: Int?
    let index: Int?

    // Keys to pick correct artwork for episodes
    let parentRatingKey: String?
    let grandparentRatingKey: String?

    // User/Player info (subset)
    let User: UserInfo?
    let Player: PlayerInfo?

    struct UserInfo: Codable, Hashable {
        let id: Int?
        let title: String?
    }

    struct PlayerInfo: Codable, Hashable {
        let title: String?
        let product: String?
        let platform: String?
    }

    enum CodingKeys: String, CodingKey {
        case ratingKey
        case type
        case title
        case year
        case grandparentTitle
        case parentIndex
        case index
        case parentRatingKey
        case grandparentRatingKey
        case User
        case Player
    }
}

// MARK: - API

final class PlexAPI {
    static let shared = PlexAPI()

    private init() {}

    private var baseURL: String {
        UserDefaults.standard.string(forKey: "plex.baseURL") ?? ""
    }

    private var token: String {
        UserDefaults.standard.string(forKey: "plex.token") ?? ""
    }

    private func join(_ base: String, _ path: String) -> String {
        if base.hasSuffix("/") {
            if path.hasPrefix("/") { return base + String(path.dropFirst()) }
            return base + path
        } else {
            if path.hasPrefix("/") { return base + path }
            return base + "/" + path
        }
    }

    /// Fetch live sessions from Plex.
    /// Returns an empty array if baseURL/token are missing or parsing fails.
    func fetchSessions() async throws -> [Metadata] {
        guard !baseURL.isEmpty, !token.isEmpty else {
            return []
        }

        let urlString = join(baseURL, "/status/sessions?X-Plex-Token=\(token)")
        guard let url = URL(string: urlString) else {
            return []
        }

        var request = URLRequest(url: url)
        // Optional helpful headers (identify client to Plex; not strictly required)
        request.setValue("menubarr", forHTTPHeaderField: "X-Plex-Product")
        request.setValue("1.0", forHTTPHeaderField: "X-Plex-Version")
        request.setValue("macOS", forHTTPHeaderField: "X-Plex-Platform")
        request.setValue("menubarr", forHTTPHeaderField: "X-Plex-Client-Identifier")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "PlexAPI", code: (response as? HTTPURLResponse)?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: text])
        }

        // Try JSON first
        if let sessions = try? JSONDecoder().decode(PlexSessionsResponse.self, from: data).MediaContainer?.Metadata {
            return sessions
        }

        // Fallback to XML
        if let xml = String(data: data, encoding: .utf8), xml.contains("<MediaContainer") {
            return parseXMLSessions(xml: xml)
        }

        return []
    }

    // MARK: - Lightweight XML parser (attributes-only + nested User/Player)

    private func parseXMLSessions(xml: String) -> [Metadata] {
        // We’ll scan for <Video ...> / <Track ...> blocks, and within each block
        // we’ll extract attributes from the root tag and from nested <User .../> and <Player .../>.
        var items: [Metadata] = []

        // Helper to find attribute="value" inside a single tag string
        func attr(_ name: String, in s: String) -> String? {
            guard let r1 = s.range(of: "\(name)=\"") else { return nil }
            let after = s[r1.upperBound...]
            guard let r2 = after.firstIndex(of: "\"") else { return nil }
            return String(after[..<r2])
        }

        // Find each item block
        let patterns = ["<Video ", "<Track ", "<Episode ", "<Movie "]
        var searchRange = xml.startIndex..<xml.endIndex

        while let (range, rootName) = nextItemBlock(in: xml, searchRange: searchRange, startPatterns: patterns) {
            let block = String(xml[range])

            // Root tag = first tag on the block (e.g., "<Video ...>")
            if let endOfRoot = block.firstIndex(of: ">") {
                let rootTag = String(block[..<block.index(after: endOfRoot)]) // includes '>'
                let ratingKey = attr("ratingKey", in: rootTag)
                let type = attr("type", in: rootTag)
                let title = attr("title", in: rootTag)
                let year = attr("year", in: rootTag).flatMap { Int($0) }
                let grandparentTitle = attr("grandparentTitle", in: rootTag)
                let parentIndex = attr("parentIndex", in: rootTag).flatMap { Int($0) }
                let index = attr("index", in: rootTag).flatMap { Int($0) }
                let parentRatingKey = attr("parentRatingKey", in: rootTag)
                let grandparentRatingKey = attr("grandparentRatingKey", in: rootTag)

                // Nested <User .../> (self-closing)
                var userTitle: String?
                if let userTag = firstTag(named: "User", in: block) {
                    userTitle = attr("title", in: userTag)
                }

                // Nested <Player .../> (self-closing)
                var playerTitle: String?
                var playerProduct: String?
                var playerPlatform: String?
                if let playerTag = firstTag(named: "Player", in: block) {
                    playerTitle = attr("title", in: playerTag)
                    playerProduct = attr("product", in: playerTag)
                    playerPlatform = attr("platform", in: playerTag)
                }

                let user = Metadata.UserInfo(id: nil, title: userTitle)
                let player = Metadata.PlayerInfo(title: playerTitle, product: playerProduct, platform: playerPlatform)

                let md = Metadata(
                    ratingKey: ratingKey,
                    type: type,
                    title: title,
                    year: year,
                    grandparentTitle: grandparentTitle,
                    parentIndex: parentIndex,
                    index: index,
                    parentRatingKey: parentRatingKey,
                    grandparentRatingKey: grandparentRatingKey,
                    User: (userTitle != nil ? user : nil),
                    Player: (playerTitle != nil || playerProduct != nil || playerPlatform != nil ? player : nil)
                )
                items.append(md)
            }

            // Advance search range
            searchRange = range.upperBound..<xml.endIndex
        }

        return items
    }

    /// Find the next full item block, e.g. `<Video ...> ... </Video>` or a self-contained `<Track .../>`.
    private func nextItemBlock(in xml: String,
                               searchRange: Range<String.Index>,
                               startPatterns: [String]) -> (Range<String.Index>, String)? {
        // Find the earliest occurrence of any start pattern
        var foundRange: Range<String.Index>?
        var foundName: String = ""
        for p in startPatterns {
            if let r = xml.range(of: p, options: [], range: searchRange), (foundRange == nil || r.lowerBound < foundRange!.lowerBound) {
                foundRange = r
                if p.contains("Video") { foundName = "Video" }
                else if p.contains("Track") { foundName = "Track" }
                else if p.contains("Episode") { foundName = "Episode" }
                else if p.contains("Movie") { foundName = "Movie" }
            }
        }
        guard let startRange = foundRange else { return nil }

        // Determine if self-closing (`.../>`) or find the corresponding end tag (`</Name>`)
        // First, find the end of the starting tag '>'
        guard let tagClose = xml[startRange.lowerBound...].firstIndex(of: ">") else { return nil }
        let startTag = xml[startRange.lowerBound...tagClose]
        if startTag.hasSuffix("/>") {
            // Self-closing: block is just the start tag
            return (startRange.lowerBound..<xml.index(after: tagClose), foundName)
        } else {
            // Find the matching end tag
            let endTag = "</\(foundName)>"
            if let endRange = xml.range(of: endTag, options: [], range: tagClose..<searchRange.upperBound) {
                return (startRange.lowerBound..<endRange.upperBound, foundName)
            } else {
                // If we can't find the closing tag, take until next start or end of doc
                let nextRange = xml.range(of: "<\(foundName) ", options: [], range: tagClose..<xml.endIndex) ?? (tagClose..<xml.endIndex)
                return (startRange.lowerBound..<nextRange.lowerBound, foundName)
            }
        }
    }

    /// Return the first `<TagName .../>` occurrence inside a block string.
    private func firstTag(named tag: String, in block: String) -> String? {
        // Search for `<Tag ` then take until the next '>'
        guard let start = block.range(of: "<\(tag) ") else { return nil }
        guard let close = block[start.lowerBound...].firstIndex(of: ">") else { return nil }
        return String(block[start.lowerBound...close])
    }
}
