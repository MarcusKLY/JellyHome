import SwiftUI

struct MediaGridView: View {
    let title: String
    let items: [MediaItem]

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 12)]

    var body: some View {
        ZStack {
            LiquidBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if items.isEmpty {
                        EmptyStateView(title: "Nothing here yet", subtitle: "Try refreshing your libraries.")
                    } else {
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(items) { item in
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
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
