import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var session: SessionStore

    var body: some View {
        ZStack {
            LiquidBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Profile")
                        .font(Theme.titleFont(28))
                        .foregroundStyle(.white)

                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            ProfileRow(title: "Name", value: session.displayName.isEmpty ? session.username : session.displayName)
                            ProfileRow(title: "Role", value: session.isAdmin ? "Admin" : "Standard")
                            ProfileRow(title: "Jellyfin", value: session.jellyfinBaseURL.isEmpty ? "Not set" : session.jellyfinBaseURL)
                            ProfileRow(title: "Seerr", value: session.seerrBaseURL.isEmpty ? "Not set" : session.seerrBaseURL)
                        }
                    }

                    Button("Sign Out") {
                        session.signOut()
                    }
                    .buttonStyle(GlassButtonStyle(tint: Color.white.opacity(0.2)))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ProfileRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(title)
                .font(Theme.bodyFont(13))
                .foregroundStyle(Theme.muted)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(Theme.bodyFont(14))
                .foregroundStyle(.white)
        }
    }
}
