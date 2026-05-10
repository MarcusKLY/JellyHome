import SwiftUI
import Combine

struct ConnectView: View {
    @EnvironmentObject private var session: SessionStore

    @State private var password: String = ""
    @State private var isSigningIn = false
    @State private var isTestingJellyfin = false
    @State private var isTestingSeerr = false
    @State private var jellyfinTestResult: String?
    @State private var seerrTestResult: String?
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        ZStack {
            LiquidBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Connect to Jellyfin")
                        .font(Theme.titleFont(32))
                        .foregroundStyle(.white)

                    Text("Add your server details to unlock the full JellyHome experience.")
                        .font(Theme.bodyFont(14))
                        .foregroundStyle(Theme.muted)

                    GlassCard {
                        VStack(spacing: 16) {
                            LabeledTextField(title: "Jellyfin URL", text: $session.jellyfinBaseURL, keyboard: .URL)
                            LabeledTextField(title: "Seerr/Jellyseerr URL", text: $session.seerrBaseURL, keyboard: .URL)
                            LabeledTextField(title: "Username", text: $session.username)
                            LabeledSecureField(title: "Password", text: $password)

                            Button {
                                Task { await signIn() }
                            } label: {
                                HStack(spacing: 10) {
                                    if isSigningIn {
                                        ProgressView()
                                            .tint(.white)
                                    }
                                    Text("Connect")
                                }
                            }
                            .buttonStyle(GlassButtonStyle(tint: Theme.accent))
                            .disabled(isSigningIn)

                            if let warning = session.lastSignInWarning {
                                Text(warning)
                                    .font(Theme.bodyFont(12))
                                    .foregroundStyle(Theme.muted)
                            }
                        }
                    }

                    SectionHeader(title: "Connection Tests")
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Button {
                                Task { await testJellyfin() }
                            } label: {
                                HStack(spacing: 10) {
                                    if isTestingJellyfin {
                                        ProgressView().tint(.white)
                                    }
                                    Text("Test Jellyfin")
                                }
                            }
                            .buttonStyle(GlassButtonStyle(tint: Theme.accentSecondary))

                            if let jellyfinTestResult {
                                Text(jellyfinTestResult)
                                    .font(Theme.bodyFont(12))
                                    .foregroundStyle(Theme.muted)
                            }

                            Button {
                                Task { await testSeerr() }
                            } label: {
                                HStack(spacing: 10) {
                                    if isTestingSeerr {
                                        ProgressView().tint(.white)
                                    }
                                    Text("Test Seerr/Jellyseerr")
                                }
                            }
                            .buttonStyle(GlassButtonStyle(tint: Theme.accentSecondary))

                            if let seerrTestResult {
                                Text(seerrTestResult)
                                    .font(Theme.bodyFont(12))
                                    .foregroundStyle(Theme.muted)
                            }
                        }
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Tips")
                                .font(Theme.bodyFont(14))
                                .foregroundStyle(.white)
                            Text("Use full URLs like https://your-server:8096")
                                .font(Theme.bodyFont(12))
                                .foregroundStyle(Theme.muted)
                            Text("Seerr is optional but enables requests and discovery")
                                .font(Theme.bodyFont(12))
                                .foregroundStyle(Theme.muted)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .alert("Connection Failed", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Could not connect to the server.")
        }
    }

    private func signIn() async {
        isSigningIn = true
        defer { isSigningIn = false }

        do {
            try await session.signIn(password: password)
            password = ""
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func testJellyfin() async {
        guard let jellyfinURL = session.jellyfinURL else {
            jellyfinTestResult = "Enter a Jellyfin URL first."
            return
        }

        isTestingJellyfin = true
        defer { isTestingJellyfin = false }

        do {
            let client = JellyfinClient(baseURL: jellyfinURL)
            let info = try await client.publicSystemInfo()
            let name = info.serverName ?? "Jellyfin"
            let version = info.version.map { "v\($0)" } ?? ""
            jellyfinTestResult = "Connected to \(name) \(version)"
        } catch {
            jellyfinTestResult = "Jellyfin test failed: \(error.localizedDescription)"
        }
    }

    private func testSeerr() async {
        guard let seerrURL = session.seerrURL else {
            seerrTestResult = "Enter a Seerr/Jellyseerr URL first."
            return
        }

        isTestingSeerr = true
        defer { isTestingSeerr = false }

        do {
            let client = SeerrClient(baseURL: seerrURL)
            let status = try await client.status()
            let version = status.version ?? ""
            seerrTestResult = version.isEmpty ? "Seerr is reachable." : "Seerr \(version) reachable."
        } catch {
            seerrTestResult = "Seerr test failed: \(error.localizedDescription)"
        }
    }
}
