import Foundation
import Combine

enum MediaSource: String, Codable {
    case jellyfin
    case seerr
}

struct MediaItem: Identifiable, Hashable {
    let id: String
    let sourceId: String
    let title: String
    let subtitle: String
    let imageURL: URL?
    let progress: Double?
    let source: MediaSource
    let mediaType: String?
}

extension MediaItem {
    var isPlayable: Bool {
        guard source == .jellyfin else { return false }
        return mediaType == "Movie" || mediaType == "Episode"
    }
}

struct SearchSection: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let items: [MediaItem]
}

struct JellyfinAuthResponse: Decodable {
    let accessToken: String
    let user: JellyfinUser

    enum CodingKeys: String, CodingKey {
        case accessToken = "AccessToken"
        case user = "User"
    }
}

struct JellyfinUser: Decodable {
    let id: String
    let name: String

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
    }
}

struct JellyfinUserProfile: Decodable {
    let id: String
    let name: String
    let policy: JellyfinUserPolicy?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case policy = "Policy"
    }
}

struct JellyfinUserPolicy: Decodable {
    let isAdministrator: Bool?

    enum CodingKeys: String, CodingKey {
        case isAdministrator = "IsAdministrator"
    }
}

struct JellyfinPublicSystemInfo: Decodable {
    let serverName: String?
    let version: String?
    let id: String?

    enum CodingKeys: String, CodingKey {
        case serverName = "ServerName"
        case version = "Version"
        case id = "Id"
    }
}

struct JellyfinSystemInfo: Decodable {
    let serverName: String?
    let version: String?
    let localAddress: String?
    let wanAddress: String?
    let id: String?

    enum CodingKeys: String, CodingKey {
        case serverName = "ServerName"
        case version = "Version"
        case localAddress = "LocalAddress"
        case wanAddress = "WanAddress"
        case id = "Id"
    }
}

struct JellyfinLibraryCounts: Decodable {
    let movieCount: Int?
    let seriesCount: Int?
    let episodeCount: Int?
    let songCount: Int?

    enum CodingKeys: String, CodingKey {
        case movieCount = "MovieCount"
        case seriesCount = "SeriesCount"
        case episodeCount = "EpisodeCount"
        case songCount = "SongCount"
    }
}

struct JellyfinSearchResponse: Decodable {
    let items: [JellyfinItem]

    enum CodingKeys: String, CodingKey {
        case items = "Items"
    }
}

struct JellyfinPlaybackInfoResponse: Decodable {
    let mediaSources: [JellyfinMediaSource]

    enum CodingKeys: String, CodingKey {
        case mediaSources = "MediaSources"
    }
}

struct JellyfinMediaSource: Decodable {
    let id: String?
    let name: String?
    let container: String?
    let path: String?
    let size: Int64?
    let directStreamUrl: String?
    let transcodingUrl: String?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case container = "Container"
        case path = "Path"
        case size = "Size"
        case directStreamUrl = "DirectStreamUrl"
        case transcodingUrl = "TranscodingUrl"
    }
}

struct JellyfinItem: Decodable {
    let id: String
    let name: String?
    let type: String?
    let productionYear: Int?
    let imageTags: [String: String]?
    let runTimeTicks: Int64?
    let userData: JellyfinUserData?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case type = "Type"
        case productionYear = "ProductionYear"
        case imageTags = "ImageTags"
        case runTimeTicks = "RunTimeTicks"
        case userData = "UserData"
    }
}

struct JellyfinUserData: Decodable {
    let playbackPositionTicks: Int64?

    enum CodingKeys: String, CodingKey {
        case playbackPositionTicks = "PlaybackPositionTicks"
    }
}

struct JellyfinMediaFoldersResponse: Decodable {
    let items: [JellyfinMediaFolder]

    enum CodingKeys: String, CodingKey {
        case items = "Items"
    }
}

struct JellyfinMediaFolder: Decodable, Identifiable {
    let id: String
    let name: String?
    let itemCount: Int?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case itemCount = "ItemCount"
    }
}

struct SeerrAuthResponse: Decodable {
    let accessToken: String
}

struct SeerrStatusResponse: Decodable {
    let version: String?
    let commitTag: String?

    enum CodingKeys: String, CodingKey {
        case version
        case commitTag = "commitTag"
    }
}

struct SeerrSearchResponse: Decodable {
    let results: [SeerrSearchItem]
}

struct SeerrDiscoverResponse: Decodable {
    let results: [SeerrSearchItem]
}

struct SeerrSearchItem: Decodable, Identifiable {
    let id: Int
    let title: String?
    let name: String?
    let mediaType: String?
    let posterPath: String?
    let overview: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case name
        case mediaType
        case posterPath
        case overview
    }

    var displayTitle: String {
        title ?? name ?? "Untitled"
    }
}

struct SeerrRequestResponse: Decodable {
    let results: [SeerrRequest]
}

struct SeerrRequest: Decodable, Identifiable {
    let id: Int
    let status: Int?
    let type: String?
    let createdAt: String?
    let media: SeerrMedia?

    enum CodingKeys: String, CodingKey {
        case id
        case status
        case type
        case createdAt
        case media
    }
}

struct SeerrMedia: Decodable {
    let title: String?
    let name: String?
    let mediaType: String?
    let posterPath: String?

    enum CodingKeys: String, CodingKey {
        case title
        case name
        case mediaType
        case posterPath
    }

    var displayTitle: String {
        title ?? name ?? "Untitled"
    }
}
