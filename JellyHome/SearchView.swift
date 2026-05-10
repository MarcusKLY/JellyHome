import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SearchViewModel()

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 12)]

    var body: some View {
        NavigationStack {
            ZStack {
                LiquidBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        GlassCard {
                            HStack(spacing: 10) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(Theme.muted)
                                TextField("Search Jellyfin + Seerr", text: $viewModel.query)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .onSubmit {
                                        Task { await viewModel.search(using: session) }
                                    }

                                if !viewModel.query.isEmpty {
                                    Button {
                                        viewModel.query = ""
                                        viewModel.sections = []
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(Theme.muted)
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

                        ForEach(viewModel.sections) { section in
                            VStack(alignment: .leading, spacing: 12) {
                                SectionHeader(title: section.title)

                                LazyVGrid(columns: columns, spacing: 14) {
                                    ForEach(section.items) { item in
                                        NavigationLink {
                                            MediaDetailView(item: item)
                                        } label: {
                                            PosterCard(item: item)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
