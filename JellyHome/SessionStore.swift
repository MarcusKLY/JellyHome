import Foundation
import Combine
import SwiftUI

@MainActor
final class SessionStore: ObservableObject {
    @Published var jellyfinBaseURL: String {
        didSet { persistSetting(key: SettingsKeys.jellyfinBaseURL, value: jellyfinBaseURL) }
    }
    @Published var seerrBaseURL: String {
        didSet { persistSetting(key: SettingsKeys.seerrBaseURL, value: seerrBaseURL) }
    }
    @Published var username: String {
        didSet { persistSetting(key: SettingsKeys.username, value: username) }
    }

    @Published var jellyfinToken: String? {
        didSet { persistToken(key: TokenKeys.jellyfinToken, value: jellyfinToken) }
    }
    @Published var jellyfinUserId: String? {
        didSet { persistToken(key: TokenKeys.jellyfinUserId, value: jellyfinUserId) }
    }
    @Published var seerrToken: String? {
        didSet { persistToken(key: TokenKeys.seerrToken, value: seerrToken) }
    }

    @Published var seerrCookie: String? {
        didSet { persistToken(key: TokenKeys.seerrCookie, value: seerrCookie) }
    }

    @Published var displayName: String = ""
    @Published var isAdmin: Bool = false
    @Published var lastSignInWarning: String?

    private let kvs = NSUbiquitousKeyValueStore.default
    private let keychain = KeychainStore(service: "com.marcuskly.JellyHome")
    private var kvsObserver: NSObjectProtocol?
    private var isBootstrapped = false
    private var isApplyingRemote = false

    init() {
        jellyfinBaseURL = kvs.string(forKey: SettingsKeys.jellyfinBaseURL) ?? ""
        seerrBaseURL = kvs.string(forKey: SettingsKeys.seerrBaseURL) ?? ""
        username = kvs.string(forKey: SettingsKeys.username) ?? ""

        jellyfinToken = keychain.get(TokenKeys.jellyfinToken)
        jellyfinUserId = keychain.get(TokenKeys.jellyfinUserId)
        seerrToken = keychain.get(TokenKeys.seerrToken)
        seerrCookie = keychain.get(TokenKeys.seerrCookie)

        kvsObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: kvs,
            queue: .main
        ) { [weak self] _ in
            Task { await self?.applyRemoteChanges() }
        }

        isBootstrapped = true
    }

    deinit {
        if let kvsObserver {
            NotificationCenter.default.removeObserver(kvsObserver)
        }
    }

    var jellyfinURL: URL? {
        makeURL(from: jellyfinBaseURL)
    }

    var seerrURL: URL? {
        makeURL(from: seerrBaseURL)
    }

    var isAuthenticated: Bool {
        jellyfinToken != nil && jellyfinUserId != nil
    }

    var jellyfinClient: JellyfinClient? {
        guard let jellyfinURL else { return nil }
        return JellyfinClient(baseURL: jellyfinURL, accessToken: jellyfinToken, userId: jellyfinUserId)
    }

    var seerrClient: SeerrClient? {
        guard let seerrURL else { return nil }
        return SeerrClient(baseURL: seerrURL, accessToken: seerrToken, sessionCookie: seerrCookie)
    }

    var seerrAuthAvailable: Bool {
        seerrToken != nil || seerrCookie != nil
    }

    func signIn(password: String) async throws {
        guard let jellyfinURL else { throw SessionError.invalidJellyfinURL }
        guard !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SessionError.missingUsername
        }
        guard !password.isEmpty else {
            throw SessionError.emptyPassword
        }

        lastSignInWarning = nil

        let jellyfin = JellyfinClient(baseURL: jellyfinURL)
        let auth: JellyfinAuthResponse
        do {
            auth = try await jellyfin.signIn(username: username, password: password)
        } catch {
            throw SessionError.jellyfinLoginFailed(error.localizedDescription)
        }
        jellyfinToken = auth.accessToken
        jellyfinUserId = auth.user.id

        let authedJellyfin = JellyfinClient(
            baseURL: jellyfinURL,
            accessToken: auth.accessToken,
            userId: auth.user.id
        )
        do {
            let profile = try await authedJellyfin.currentUser()
            displayName = profile.name
            isAdmin = profile.policy?.isAdministrator ?? false
        } catch {
            displayName = username
            isAdmin = false
        }

        if let seerrURL {
            let seerr = SeerrClient(baseURL: seerrURL)
            do {
                let seerrAuth = try await seerr.signInWithJellyfin(username: username, password: password)
                seerrToken = seerrAuth.accessToken
                seerrCookie = seerrAuth.sessionCookie
            } catch {
                seerrToken = nil
                seerrCookie = nil
                lastSignInWarning = "Seerr login failed: \(error.localizedDescription)"
            }
        }
    }

    func signInSeerr(password: String) async throws {
        guard let seerrURL else { throw SessionError.invalidSeerrURL }
        guard !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SessionError.missingUsername
        }
        guard !password.isEmpty else {
            throw SessionError.emptyPassword
        }

        lastSignInWarning = nil
        let seerr = SeerrClient(baseURL: seerrURL)
        do {
            let seerrAuth = try await seerr.signInWithJellyfin(username: username, password: password)
            seerrToken = seerrAuth.accessToken
            seerrCookie = seerrAuth.sessionCookie
        } catch {
            seerrToken = nil
            seerrCookie = nil
            throw SessionError.seerrLoginFailed(error.localizedDescription)
        }
    }

    func signOut() {
        jellyfinToken = nil
        jellyfinUserId = nil
        seerrToken = nil
        seerrCookie = nil
        displayName = ""
        isAdmin = false
        lastSignInWarning = nil
    }

    private func persistSetting(key: String, value: String) {
        guard isBootstrapped, !isApplyingRemote else { return }
        kvs.set(value, forKey: key)
        kvs.synchronize()
    }

    private func persistToken(key: String, value: String?) {
        guard isBootstrapped else { return }
        if let value {
            keychain.set(value, for: key)
        } else {
            keychain.delete(key)
        }
    }

    private func applyRemoteChanges() {
        isApplyingRemote = true
        jellyfinBaseURL = kvs.string(forKey: SettingsKeys.jellyfinBaseURL) ?? jellyfinBaseURL
        seerrBaseURL = kvs.string(forKey: SettingsKeys.seerrBaseURL) ?? seerrBaseURL
        username = kvs.string(forKey: SettingsKeys.username) ?? username
        isApplyingRemote = false
    }

    private func makeURL(from string: String) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return URL(string: trimmed)
        }
        return URL(string: "http://\(trimmed)")
    }
}

enum SessionError: LocalizedError {
    case invalidJellyfinURL
    case invalidSeerrURL
    case missingUsername
    case emptyPassword
    case jellyfinLoginFailed(String)
    case seerrLoginFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidJellyfinURL:
            return "Enter a valid Jellyfin server URL."
        case .invalidSeerrURL:
            return "Enter a valid Seerr/Jellyseerr server URL."
        case .missingUsername:
            return "Enter your Jellyfin username."
        case .emptyPassword:
            return "Enter your Jellyfin password."
        case .jellyfinLoginFailed(let detail):
            return "Jellyfin login failed: \(detail)"
        case .seerrLoginFailed(let detail):
            return "Seerr login failed: \(detail)"
        }
    }
}

private enum SettingsKeys {
    static let jellyfinBaseURL = "jellyfinBaseURL"
    static let seerrBaseURL = "seerrBaseURL"
    static let username = "username"
}

private enum TokenKeys {
    static let jellyfinToken = "jellyfinToken"
    static let jellyfinUserId = "jellyfinUserId"
    static let seerrToken = "seerrToken"
    static let seerrCookie = "seerrCookie"
}
