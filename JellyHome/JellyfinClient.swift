import Foundation

protocol JellyfinClientProtocol {
    func signIn(username: String, password: String) async throws -> JellyfinAuthResponse
    func currentUser() async throws -> JellyfinUserProfile
    func publicSystemInfo() async throws -> JellyfinPublicSystemInfo
    func systemInfo() async throws -> JellyfinSystemInfo
    func libraryCounts() async throws -> JellyfinLibraryCounts
    func resumeItems(limit: Int) async throws -> [MediaItem]
    func latestMovies(limit: Int) async throws -> [MediaItem]
    func latestSeries(limit: Int) async throws -> [MediaItem]
    func mediaFolders() async throws -> [JellyfinMediaFolder]
    func refreshLibrary() async throws
    func restartServer() async throws
    func search(query: String) async throws -> [MediaItem]
    func streamURL(for itemId: String) -> URL?
    func playbackURL(for itemId: String) async throws -> URL
}

final class JellyfinClient: JellyfinClientProtocol {
    private let baseURL: URL
    private let accessToken: String?
    private let userId: String?
    private let session: URLSession

    init(baseURL: URL, accessToken: String? = nil, userId: String? = nil, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.accessToken = accessToken
        self.userId = userId
        self.session = session
    }

    func signIn(username: String, password: String) async throws -> JellyfinAuthResponse {
        let request = JellyfinAuthRequest(username: username, pw: password)
        let client = APIClient(baseURL: baseURL, session: session, defaultHeaders: baseHeaders)
        return try await client.request("/Users/AuthenticateByName", method: .post, body: request)
    }

    func currentUser() async throws -> JellyfinUserProfile {
        let client = APIClient(baseURL: baseURL, session: session, defaultHeaders: baseHeaders)
        return try await client.request("/Users/Me", headers: authHeaders)
    }

    func publicSystemInfo() async throws -> JellyfinPublicSystemInfo {
        let client = APIClient(baseURL: baseURL, session: session, defaultHeaders: baseHeaders)
        return try await client.request("/System/Info/Public")
    }

    func systemInfo() async throws -> JellyfinSystemInfo {
        let client = APIClient(baseURL: baseURL, session: session, defaultHeaders: baseHeaders)
        return try await client.request("/System/Info", headers: authHeaders)
    }

    func libraryCounts() async throws -> JellyfinLibraryCounts {
        let client = APIClient(baseURL: baseURL, session: session, defaultHeaders: baseHeaders)
        return try await client.request("/Items/Counts", headers: authHeaders)
    }

    func resumeItems(limit: Int) async throws -> [MediaItem] {
        guard let userId else { return [] }
        let items = try await fetchItems(
            path: "/Users/\(userId)/Items/Resume",
            queryItems: [
                URLQueryItem(name: "Limit", value: String(limit)),
                URLQueryItem(name: "Recursive", value: "true"),
                URLQueryItem(name: "Fields", value: "ImageTags,RunTimeTicks,UserData,ProductionYear"),
                URLQueryItem(name: "ImageTypeLimit", value: "1"),
                URLQueryItem(name: "EnableImageTypes", value: "Primary")
            ]
        )
        return items.map { mapToMediaItem($0, progress: playbackProgress(for: $0)) }
    }

    func latestMovies(limit: Int) async throws -> [MediaItem] {
        guard let userId else { return [] }
        let items = try await fetchLatestItems(
            path: "/Users/\(userId)/Items/Latest",
            queryItems: [
                URLQueryItem(name: "IncludeItemTypes", value: "Movie"),
                URLQueryItem(name: "Limit", value: String(limit)),
                URLQueryItem(name: "Fields", value: "ImageTags,ProductionYear"),
                URLQueryItem(name: "ImageTypeLimit", value: "1"),
                URLQueryItem(name: "EnableImageTypes", value: "Primary")
            ]
        )
        return items.map { mapToMediaItem($0, progress: nil) }
    }

    func latestSeries(limit: Int) async throws -> [MediaItem] {
        guard let userId else { return [] }
        let items = try await fetchLatestItems(
            path: "/Users/\(userId)/Items/Latest",
            queryItems: [
                URLQueryItem(name: "IncludeItemTypes", value: "Series"),
                URLQueryItem(name: "Limit", value: String(limit)),
                URLQueryItem(name: "Fields", value: "ImageTags,ProductionYear"),
                URLQueryItem(name: "ImageTypeLimit", value: "1"),
                URLQueryItem(name: "EnableImageTypes", value: "Primary")
            ]
        )
        return items.map { mapToMediaItem($0, progress: nil) }
    }

    func mediaFolders() async throws -> [JellyfinMediaFolder] {
        let client = APIClient(baseURL: baseURL, session: session, defaultHeaders: baseHeaders)
        let response: JellyfinMediaFoldersResponse = try await client.request("/Library/MediaFolders", headers: authHeaders)
        return response.items
    }

    func refreshLibrary() async throws {
        let client = APIClient(baseURL: baseURL, session: session, defaultHeaders: baseHeaders)
        let _: EmptyResponse = try await client.request("/Library/Refresh", method: .post, headers: authHeaders)
    }

    func restartServer() async throws {
        let client = APIClient(baseURL: baseURL, session: session, defaultHeaders: baseHeaders)
        let _: EmptyResponse = try await client.request("/System/Restart", method: .post, headers: authHeaders)
    }

    func search(query: String) async throws -> [MediaItem] {
        let client = APIClient(baseURL: baseURL, session: session, defaultHeaders: baseHeaders)
        let response: JellyfinSearchResponse = try await client.request(
            "/Items",
            queryItems: [
                URLQueryItem(name: "SearchTerm", value: query),
                URLQueryItem(name: "Recursive", value: "true"),
                URLQueryItem(name: "IncludeItemTypes", value: "Movie,Series,Episode"),
                URLQueryItem(name: "Fields", value: "ImageTags,ProductionYear"),
                URLQueryItem(name: "Limit", value: "24")
            ],
            headers: authHeaders
        )

        return response.items.map { mapToMediaItem($0, progress: nil) }
    }

    func streamURL(for itemId: String) -> URL? {
        guard let accessToken else { return nil }
        var url = baseURL
        url.appendPathComponent("Videos")
        url.appendPathComponent(itemId)
        url.appendPathComponent("stream")

        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.queryItems = [
            URLQueryItem(name: "static", value: "true"),
            URLQueryItem(name: "api_key", value: accessToken)
        ]
        return components.url
    }

    func playbackURL(for itemId: String) async throws -> URL {
        let info = try await playbackInfo(itemId: itemId)
        if let direct = info.mediaSources.first?.directStreamUrl,
           let url = resolveStreamURL(direct) {
            return url
        }

        if let transcode = info.mediaSources.first?.transcodingUrl,
           let url = resolveStreamURL(transcode) {
            return url
        }

        if let fallback = streamURL(for: itemId) {
            return fallback
        }

        throw PlaybackError.noPlayableStream
    }

    private var baseHeaders: [String: String] {
        [
            "X-Emby-Authorization": jellyfinAuthorizationHeader(),
            "Accept": "application/json"
        ]
    }

    private var authHeaders: [String: String] {
        var headers = baseHeaders
        if let accessToken {
            headers["X-Emby-Token"] = accessToken
        }
        if let userId {
            headers["X-Emby-UserId"] = userId
        }
        return headers
    }

    private func jellyfinAuthorizationHeader() -> String {
        let deviceName = "iPhone"
        let version = "1.0"
        let deviceId = DeviceIdentity.id
        return "MediaBrowser Client=\"JellyHome\", Device=\"\(deviceName)\", DeviceId=\"\(deviceId)\", Version=\"\(version)\""
    }

    private func imageURL(for item: JellyfinItem) -> URL? {
        guard let tag = item.imageTags?["Primary"] else { return nil }

        var url = baseURL
        url.appendPathComponent("Items")
        url.appendPathComponent(item.id)
        url.appendPathComponent("Images")
        url.appendPathComponent("Primary")

        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.queryItems = [
            URLQueryItem(name: "maxWidth", value: "600"),
            URLQueryItem(name: "quality", value: "85"),
            URLQueryItem(name: "tag", value: tag)
        ]
        return components.url
    }

    private func fetchItems(path: String, queryItems: [URLQueryItem]) async throws -> [JellyfinItem] {
        let client = APIClient(baseURL: baseURL, session: session, defaultHeaders: baseHeaders)
        let response: JellyfinSearchResponse = try await client.request(path, queryItems: queryItems, headers: authHeaders)
        return response.items
    }

    private func fetchLatestItems(path: String, queryItems: [URLQueryItem]) async throws -> [JellyfinItem] {
        let client = APIClient(baseURL: baseURL, session: session, defaultHeaders: baseHeaders)
        return try await client.request(path, queryItems: queryItems, headers: authHeaders)
    }

    private func mapToMediaItem(_ item: JellyfinItem, progress: Double?) -> MediaItem {
        MediaItem(
            id: item.id,
            sourceId: item.id,
            title: item.name ?? "Untitled",
            subtitle: item.productionYear.map(String.init) ?? (item.type ?? "Item"),
            imageURL: imageURL(for: item),
            progress: progress,
            source: .jellyfin,
            mediaType: item.type
        )
    }

    private func playbackProgress(for item: JellyfinItem) -> Double? {
        guard let runtime = item.runTimeTicks, runtime > 0,
              let position = item.userData?.playbackPositionTicks else {
            return nil
        }
        let value = Double(position) / Double(runtime)
        return min(max(value, 0), 1)
    }

    private func playbackInfo(itemId: String) async throws -> JellyfinPlaybackInfoResponse {
        let client = APIClient(baseURL: baseURL, session: session, defaultHeaders: baseHeaders)
        var queryItems: [URLQueryItem] = []
        if let userId {
            queryItems.append(URLQueryItem(name: "UserId", value: userId))
        }
        return try await client.request(
            "/Items/\(itemId)/PlaybackInfo",
            method: .post,
            queryItems: queryItems,
            body: JellyfinPlaybackInfoRequest(),
            headers: authHeaders
        )
    }

    private func resolveStreamURL(_ value: String) -> URL? {
        if let url = URL(string: value), url.scheme != nil {
            return url
        }

        let trimmed = value.hasPrefix("/") ? String(value.dropFirst()) : value
        var url = baseURL
        url.appendPathComponent(trimmed)
        return url
    }
}

enum PlaybackError: LocalizedError {
    case noPlayableStream

    var errorDescription: String? {
        switch self {
        case .noPlayableStream:
            return "No playable stream was returned by Jellyfin."
        }
    }
}

private struct JellyfinPlaybackInfoRequest: Encodable {}

private struct JellyfinAuthRequest: Encodable {
    let username: String
    let pw: String

    enum CodingKeys: String, CodingKey {
        case username = "Username"
        case pw = "Pw"
    }
}
