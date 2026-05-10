import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var session: SessionStore
    @StateObject private var viewModel = HomeViewModel()

    var body: some View {
        ZStack {
            LiquidBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if !viewModel.heroItems.isEmpty {
                        HeroCarousel(items: viewModel.heroItems, primaryActionTitle: "Play", secondaryActionTitle: "Favorite")
                            .padding(.top, 8)
                    }

                    if viewModel.isLoading {
                        ProgressView()
                            .tint(Theme.accent)
                    }

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(Theme.bodyFont(12))
                            .foregroundStyle(Theme.muted)
                    }

                    if viewModel.continueWatching.isEmpty {
                        EmptyStateView(title: "Nothing in progress", subtitle: "Start watching to see progress here.")
                    } else {
                        MediaRow(
                            title: "Continue Watching",
                            items: viewModel.continueWatching,
                            seeAllDestination: AnyView(MediaGridView(title: "Continue Watching", items: viewModel.continueWatching))
                        )
                    }

                    if !viewModel.movies.isEmpty {
                        MediaRow(
                            title: "Movies",
                            items: viewModel.movies,
                            seeAllDestination: AnyView(MediaGridView(title: "Movies", items: viewModel.movies))
                        )
                    }

                    if !viewModel.series.isEmpty {
                        MediaRow(
                            title: "Series",
                            items: viewModel.series,
                            seeAllDestination: AnyView(MediaGridView(title: "Series", items: viewModel.series))
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load(using: session)
        }
    }
}
