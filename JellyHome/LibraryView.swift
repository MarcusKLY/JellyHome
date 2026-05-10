import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var session: SessionStore
    @StateObject private var viewModel = LibraryViewModel()

    var body: some View {
        ZStack {
            LiquidBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SectionHeader(title: "Library")

                    GlassCard {
                        VStack(spacing: 16) {
                            if viewModel.libraries.isEmpty {
                                EmptyStateView(title: "No libraries found", subtitle: "Check your Jellyfin connection.")
                            } else {
                                ForEach(viewModel.libraries) { folder in
                                    LibraryFolderRow(folder: folder)
                                }
                            }
                        }
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

                    if !viewModel.recent.isEmpty {
                        SectionHeader(title: "Recently Added")
                        MediaRow(
                            title: "Movies",
                            items: viewModel.recent,
                            seeAllDestination: AnyView(MediaGridView(title: "Recently Added", items: viewModel.recent))
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Library")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load(using: session)
        }
    }
}

private struct LibraryFolderRow: View {
    let folder: JellyfinMediaFolder

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "tray.2")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 36, height: 36)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(folder.name ?? "Library")
                    .font(Theme.bodyFont(16))
                    .foregroundStyle(.white)
                Text(folder.itemCount.map { "\($0) items" } ?? "")
                    .font(Theme.bodyFont(12))
                    .foregroundStyle(Theme.muted)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(Theme.muted)
        }
    }
}
