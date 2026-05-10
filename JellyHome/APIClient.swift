import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpStatus(Int, String?)
    case decodingFailed(String?)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The server URL is invalid."
        case .invalidResponse:
            return "The server response was invalid."
        case .httpStatus(let code, let message):
            if let message, !message.isEmpty {
                return "The server returned status code \(code): \(message)"
            }
            return "The server returned status code \(code)."
        case .decodingFailed(let message):
            return message ?? "The response could not be decoded."
        }
    }
}

struct APIClient {
    let baseURL: URL
    let session: URLSession
    var defaultHeaders: [String: String]

    init(baseURL: URL, session: URLSession = .shared, defaultHeaders: [String: String] = [:]) {
        self.baseURL = baseURL
        self.session = session
        self.defaultHeaders = defaultHeaders
    }

    func request<T: Decodable>(
        _ path: String,
        method: HTTPMethod = .get,
        queryItems: [URLQueryItem] = [],
        body: Encodable? = nil,
        headers: [String: String] = [:]
    ) async throws -> T {
        let (data, _) = try await requestRaw(
            path,
            method: method,
            queryItems: queryItems,
            body: body,
            headers: headers
        )

        if data.isEmpty, T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decodingFailed(parseErrorMessage(from: data))
        }
    }

    func requestRaw(
        _ path: String,
        method: HTTPMethod = .get,
        queryItems: [URLQueryItem] = [],
        body: Encodable? = nil,
        headers: [String: String] = [:]
    ) async throws -> (Data, HTTPURLResponse) {
        guard let url = buildURL(path: path, queryItems: queryItems) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        defaultHeaders.merging(headers, uniquingKeysWith: { _, new in new }).forEach {
            request.setValue($0.value, forHTTPHeaderField: $0.key)
        }

        if let body {
            request.httpBody = try JSONEncoder().encode(AnyEncodable(body))
            if request.value(forHTTPHeaderField: "Content-Type") == nil {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = parseErrorMessage(from: data)
            throw APIError.httpStatus(httpResponse.statusCode, message)
        }

        return (data, httpResponse)
    }

    private func buildURL(path: String, queryItems: [URLQueryItem]) -> URL? {
        let trimmedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        var url = baseURL
        url.appendPathComponent(trimmedPath)

        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        return components.url
    }

    private func parseErrorMessage(from data: Data) -> String? {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let message = json["message"] as? String { return message }
            if let error = json["error"] as? String { return error }
            if let detail = json["detail"] as? String { return detail }
            if let errors = json["errors"] as? [String], let first = errors.first { return first }
        }

        if let text = String(data: data, encoding: .utf8) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        return nil
    }
}

struct AnyEncodable: Encodable {
    private let encodeBlock: (Encoder) throws -> Void

    init<T: Encodable>(_ value: T) {
        encodeBlock = value.encode
    }

    func encode(to encoder: Encoder) throws {
        try encodeBlock(encoder)
    }
}

struct EmptyResponse: Decodable {}
