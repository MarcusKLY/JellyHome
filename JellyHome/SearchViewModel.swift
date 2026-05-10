import SwiftUI
import Combine

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var sections: [SearchSection] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func search(using session: SessionStore) async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            sections = []
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            async let jellyfinItems = fetchJellyfinResults(query: trimmedQuery, session: session)
            async let seerrItems = fetchSeerrResults(query: trimmedQuery, session: session)
            let (jellyfin, seerr) = try await (jellyfinItems, seerrItems)

            var newSections: [SearchSection] = []
            if !jellyfin.isEmpty {
                newSections.append(SearchSection(title: "On Server", items: jellyfin))
            }
            if !seerr.isEmpty {
                newSections.append(SearchSection(title: "Catalog", items: seerr))
            }
            sections = newSections
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func fetchJellyfinResults(query: String, session: SessionStore) async throws -> [MediaItem] {
        guard let client = session.jellyfinClient, session.jellyfinToken != nil else { return [] }
        return try await client.search(query: query)
    }

    private func fetchSeerrResults(query: String, session: SessionStore) async throws -> [MediaItem] {
        guard let client = session.seerrClient, session.seerrAuthAvailable else { return [] }
        return try await client.search(query: query)
    }
}
