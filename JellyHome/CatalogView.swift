import SwiftUI

struct CatalogView: View {
    @EnvironmentObject private var session: SessionStore
    @StateObject private var viewModel = CatalogViewModel()
    @State private var showSeerrSignIn = false

    var body: some View {
        ZStack {
            LiquidBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if !viewModel.heroItems.isEmpty {
                        HeroCarousel(items: viewModel.heroItems, primaryActionTitle: "Request", secondaryActionTitle: "Details")
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

                    if !session.seerrAuthAvailable {
                        EmptyStateView(title: "Seerr not connected", subtitle: "Sign in to Seerr to browse discovery.")
                        Button("Sign In to Seerr") {
                            showSeerrSignIn = true
                        }
                        .buttonStyle(GlassButtonStyle(tint: Theme.accentSecondary))

                        if let warning = session.lastSignInWarning {
                            Text(warning)
                                .font(Theme.bodyFont(12))
                                .foregroundStyle(Theme.muted)
                        }
                    }

                    if !viewModel.trending.isEmpty {
                        MediaRow(
                            title: "Trending",
                            items: viewModel.trending,
                            seeAllDestination: AnyView(MediaGridView(title: "Trending", items: viewModel.trending))
                        )
                    }

                    if !viewModel.popular.isEmpty {
                        MediaRow(
                            title: "Popular",
                            items: viewModel.popular,
                            seeAllDestination: AnyView(MediaGridView(title: "Popular", items: viewModel.popular))
                        )
                    }

                    if !viewModel.upcoming.isEmpty {
                        MediaRow(
                            title: "Upcoming",
                            items: viewModel.upcoming,
                            seeAllDestination: AnyView(MediaGridView(title: "Upcoming", items: viewModel.upcoming))
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Catalog")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load(using: session)
        }
        .sheet(isPresented: $showSeerrSignIn) {
            SeerrSignInView()
        }
        .onChange(of: session.seerrAuthAvailable) { _, _ in
            Task { await viewModel.load(using: session) }
        }
    }
}
