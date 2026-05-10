import SwiftUI
import Combine

@MainActor
final class CatalogViewModel: ObservableObject {
    @Published var heroItems: [MediaItem] = []
    @Published var trending: [MediaItem] = []
    @Published var popular: [MediaItem] = []
    @Published var upcoming: [MediaItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load(using session: SessionStore) async {
        guard let client = session.seerrClient else {
            errorMessage = "Connect to Seerr/Jellyseerr to load Catalog."
            return
        }

        guard session.seerrAuthAvailable else {
            errorMessage = "Sign in to Seerr to load Catalog."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            async let trendingItems = client.discoverTrending()
            async let popularItems = client.discoverPopular()
            async let upcomingItems = client.discoverUpcoming()

            let (trending, popular, upcoming) = try await (trendingItems, popularItems, upcomingItems)
            self.trending = trending
            self.popular = popular
            self.upcoming = upcoming
            heroItems = Array(trending.prefix(5))
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
