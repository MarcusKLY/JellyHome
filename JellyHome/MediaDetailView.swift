import AVKit
import SwiftUI

struct MediaDetailView: View {
    @EnvironmentObject private var session: SessionStore
    @StateObject private var player = PlayerCoordinator()

    let item: MediaItem

    @State private var isPlayerPresented = false
    @State private var isRequesting = false
    @State private var isLoadingPlayback = false
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        ZStack {
            LiquidBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    AsyncImage(url: item.imageURL) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .scaledToFill()
                        } else {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                        }
                    }
                    .frame(height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.title)
                            .font(Theme.titleFont(26))
                            .foregroundStyle(.white)
                        Text(item.subtitle)
                            .font(Theme.bodyFont(14))
                            .foregroundStyle(Theme.muted)
                    }

                    if item.source == .jellyfin {
                        Button {
                            Task { await startPlayback() }
                        } label: {
                            HStack(spacing: 10) {
                                if isLoadingPlayback {
                                    ProgressView().tint(.white)
                                }
                                Text(item.isPlayable ? "Play" : "Not Playable")
                            }
                        }
                        .buttonStyle(GlassButtonStyle(tint: Theme.accent))
                        .disabled(isLoadingPlayback || !item.isPlayable)

                        if !item.isPlayable {
                            Text("This title needs an episode/stream selection view.")
                                .font(Theme.bodyFont(12))
                                .foregroundStyle(Theme.muted)
                        }
                    } else {
                        Button {
                            Task { await requestItem() }
                        } label: {
                            HStack(spacing: 10) {
                                if isRequesting {
                                    ProgressView().tint(.white)
                                }
                                Text("Request")
                            }
                        }
                        .buttonStyle(GlassButtonStyle(tint: Theme.accent))
                        .disabled(isRequesting)
                    }

                    if let mediaType = item.mediaType {
                        Text("Type: \(mediaType.capitalized)")
                            .font(Theme.bodyFont(12))
                            .foregroundStyle(Theme.muted)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isPlayerPresented, onDismiss: { player.stop() }) {
            PlayerViewController(player: player.player)
                .ignoresSafeArea()
        }
        .alert("Action Failed", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Something went wrong.")
        }
    }

    private func startPlayback() async {
        guard item.isPlayable else {
            errorMessage = "This item is not directly playable yet."
            showError = true
            return
        }
        guard let client = session.jellyfinClient else {
            errorMessage = "Jellyfin is not connected."
            showError = true
            return
        }

        isLoadingPlayback = true
        defer { isLoadingPlayback = false }

        do {
            let url = try await client.playbackURL(for: item.sourceId)
            player.play(url: url)
            isPlayerPresented = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func requestItem() async {
        guard let client = session.seerrClient else {
            errorMessage = "Seerr is not connected."
            showError = true
            return
        }
        guard let mediaId = Int(item.sourceId) else {
            errorMessage = "Invalid media identifier."
            showError = true
            return
        }

        isRequesting = true
        defer { isRequesting = false }

        do {
            let type = item.mediaType ?? "movie"
            try await client.createRequest(mediaType: type, mediaId: mediaId, is4k: false, seasons: nil)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
