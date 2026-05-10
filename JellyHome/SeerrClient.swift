import Foundation

protocol SeerrClientProtocol {
    func signInWithJellyfin(username: String, password: String) async throws -> SeerrAuthResult
    func status() async throws -> SeerrStatusResponse
    func search(query: String) async throws -> [MediaItem]
    func discoverTrending() async throws -> [MediaItem]
    func discoverPopular() async throws -> [MediaItem]
    func discoverUpcoming() async throws -> [MediaItem]
    func requestQueue() async throws -> [SeerrRequest]
    func createRequest(mediaType: String, mediaId: Int, is4k: Bool, seasons: [Int]?) async throws
    func approveRequest(id: Int) async throws
    func declineRequest(id: Int) async throws
}

final class SeerrClient: SeerrClientProtocol {
    private let baseURL: URL
    private let accessToken: String?
    private let sessionCookie: String?
    private let session: URLSession

    init(baseURL: URL, accessToken: String? = nil, sessionCookie: String? = nil, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.accessToken = accessToken
        self.sessionCookie = sessionCookie
        self.session = session
    }

    func signInWithJellyfin(username: String, password: String) async throws -> SeerrAuthResult {
        let request = SeerrJellyfinAuthRequest(username: username, password: password, rememberMe: true)
        let client = APIClient(baseURL: baseURL, session: session, defaultHeaders: baseHeaders)
        let (data, response) = try await client.requestRaw("/api/v1/auth/jellyfin", method: .post, body: request)

        let token = (try? JSONDecoder().decode(SeerrAuthResponse.self, from: data))?.accessToken
        let cookie = sessionCookie(from: response)

        if token == nil && cookie == nil {
            throw SeerrAuthError.missingSession
        }

        return SeerrAuthResult(accessToken: token, sessionCookie: cookie)
    }

    func status() async throws -> SeerrStatusResponse {
        let client = APIClient(baseURL: baseURL, session: session, defaultHeaders: baseHeaders)
        return try await client.request("/api/v1/status")
    }

    func search(query: String) async throws -> [MediaItem] {
        let client = APIClient(baseURL: baseURL, session: session, defaultHeaders: baseHeaders)
        let response: SeerrSearchResponse = try await client.request(
            "/api/v1/search",
            queryItems: [URLQueryItem(name: "query", value: query)],
            headers: authHeaders
        )
        return response.results.map(mapToMediaItem)
    }

    func discoverTrending() async throws -> [MediaItem] {
        do {
            return try await discover(path: "/api/v1/discover/trending")
        } catch APIError.httpStatus(let code, _) where code == 404 {
            return try await discoverMovies(sortBy: "popularity.desc")
        }
    }

    func discoverPopular() async throws -> [MediaItem] {
        do {
            return try await discover(path: "/api/v1/discover/popular")
        } catch APIError.httpStatus(let code, _) where code == 404 {
            return try await discoverTV(sortBy: "popularity.desc")
        }
    }

    func discoverUpcoming() async throws -> [MediaItem] {
        do {
            return try await discover(path: "/api/v1/discover/upcoming")
        } catch APIError.httpStatus(let code, _) where code == 404 {
            return try await discoverMovies(sortBy: "primary_release_date.desc")
        }
    }

    func requestQueue() async throws -> [SeerrRequest] {
        let client = APIClient(baseURL: baseURL, session: session, defaultHeaders: baseHeaders)
        let response: SeerrRequestResponse = try await client.request("/api/v1/request", headers: authHeaders)
        return response.results
    }

    func createRequest(mediaType: String, mediaId: Int, is4k: Bool, seasons: [Int]?) async throws {
        let request = SeerrCreateRequest(mediaType: mediaType, mediaId: mediaId, is4k: is4k, seasons: seasons)
        let client = APIClient(baseURL: baseURL, session: session, defaultHeaders: baseHeaders)
        let _: EmptyResponse = try await client.request("/api/v1/request", method: .post, body: request, headers: authHeaders)
    }

    func approveRequest(id: Int) async throws {
        let client = APIClient(baseURL: baseURL, session: session, defaultHeaders: baseHeaders)
        let _: EmptyResponse = try await client.request("/api/v1/request/\(id)/approve", method: .post, headers: authHeaders)
    }

    func declineRequest(id: Int) async throws {
        let client = APIClient(baseURL: baseURL, session: session, defaultHeaders: baseHeaders)
        let _: EmptyResponse = try await client.request("/api/v1/request/\(id)/decline", method: .post, headers: authHeaders)
    }

    private var baseHeaders: [String: String] {
        ["Accept": "application/json"]
    }

    private var authHeaders: [String: String] {
        var headers = baseHeaders
        if let accessToken {
            headers["Authorization"] = "Bearer \(accessToken)"
        }
        if let sessionCookie {
            headers["Cookie"] = sessionCookie
        }
        return headers
    }

    private func mapToMediaItem(_ item: SeerrSearchItem) -> MediaItem {
        MediaItem(
            id: "seerr-\(item.id)",
            sourceId: String(item.id),
            title: item.displayTitle,
            subtitle: item.mediaType?.capitalized ?? "Catalog",
            imageURL: imageURL(for: item.posterPath),
            progress: nil,
            source: .seerr,
            mediaType: item.mediaType
        )
    }

    private func discover(path: String, queryItems: [URLQueryItem] = []) async throws -> [MediaItem] {
        let client = APIClient(baseURL: baseURL, session: session, defaultHeaders: baseHeaders)
        let response: SeerrDiscoverResponse = try await client.request(path, queryItems: queryItems, headers: authHeaders)
        return response.results.map(mapToMediaItem)
    }

    private func discoverMovies(sortBy: String?) async throws -> [MediaItem] {
        var queryItems: [URLQueryItem] = []
        if let sortBy {
            queryItems.append(URLQueryItem(name: "sortBy", value: sortBy))
        }
        return try await discover(path: "/api/v1/discover/movies", queryItems: queryItems)
    }

    private func discoverTV(sortBy: String?) async throws -> [MediaItem] {
        var queryItems: [URLQueryItem] = []
        if let sortBy {
            queryItems.append(URLQueryItem(name: "sortBy", value: sortBy))
        }
        return try await discover(path: "/api/v1/discover/tv", queryItems: queryItems)
    }

    private func imageURL(for posterPath: String?) -> URL? {
        guard let posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500\(posterPath)")
    }

    private func sessionCookie(from response: HTTPURLResponse) -> String? {
        var headers: [String: String] = [:]
        for (key, value) in response.allHeaderFields {
            if let key = key as? String, let value = value as? String {
                headers[key] = value
            }
        }

        let cookies = HTTPCookie.cookies(withResponseHeaderFields: headers, for: baseURL)
        if let session = cookies.first(where: { $0.name.contains("connect.sid") }) {
            return "\(session.name)=\(session.value)"
        }
        if let first = cookies.first {
            return "\(first.name)=\(first.value)"
        }
        return nil
    }
}

struct SeerrAuthResult {
    let accessToken: String?
    let sessionCookie: String?
}

enum SeerrAuthError: LocalizedError {
    case missingSession

    var errorDescription: String? {
        switch self {
        case .missingSession:
            return "Seerr login succeeded, but no session token was returned."
        }
    }
}

private struct SeerrJellyfinAuthRequest: Encodable {
    let username: String
    let password: String
    let rememberMe: Bool
}

private struct SeerrCreateRequest: Encodable {
    let mediaType: String
    let mediaId: Int
    let is4k: Bool
    let seasons: [Int]?

    enum CodingKeys: String, CodingKey {
        case mediaType
        case mediaId
        case is4k
        case seasons
    }
}
