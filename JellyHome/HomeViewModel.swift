import SwiftUI
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var heroItems: [MediaItem] = []
    @Published var continueWatching: [MediaItem] = []
    @Published var movies: [MediaItem] = []
    @Published var series: [MediaItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load(using session: SessionStore) async {
        guard let client = session.jellyfinClient else {
            errorMessage = "Connect to a Jellyfin server to load Home."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            async let resumeItems = client.resumeItems(limit: 12)
            async let latestMovies = client.latestMovies(limit: 12)
            async let latestSeries = client.latestSeries(limit: 12)

            let (resume, movies, series) = try await (resumeItems, latestMovies, latestSeries)
            continueWatching = resume
            self.movies = movies
            self.series = series

            if !movies.isEmpty {
                heroItems = Array(movies.prefix(5))
            } else {
                heroItems = Array(series.prefix(5))
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
