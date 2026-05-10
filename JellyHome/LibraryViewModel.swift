import SwiftUI
import Combine

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published var libraries: [JellyfinMediaFolder] = []
    @Published var recent: [MediaItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load(using session: SessionStore) async {
        guard let client = session.jellyfinClient else {
            errorMessage = "Connect to a Jellyfin server to load Library."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            async let folders = client.mediaFolders()
            async let latestMovies = client.latestMovies(limit: 12)
            let (foldersResult, movies) = try await (folders, latestMovies)
            libraries = foldersResult
            recent = movies
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
