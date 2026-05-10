import SwiftUI

struct AdminView: View {
    @EnvironmentObject private var session: SessionStore

    @State private var password: String = ""
    @State private var isSigningIn = false
    @State private var serverInfo: JellyfinSystemInfo?
    @State private var libraryCounts: JellyfinLibraryCounts?
    @State private var requests: [SeerrRequest] = []
    @State private var jellyfinTestResult: String?
    @State private var seerrTestResult: String?
    @State private var isTestingJellyfin = false
    @State private var isTestingSeerr = false
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        ZStack {
            LiquidBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    SectionHeader(title: "Server Configuration")

                    GlassCard {
                        VStack(spacing: 16) {
                            LabeledTextField(title: "Jellyfin URL", text: $session.jellyfinBaseURL, keyboard: .URL)
                            LabeledTextField(title: "Seerr URL", text: $session.seerrBaseURL, keyboard: .URL)
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
                                    Text("Sign In")
                                }
                            }
                            .buttonStyle(GlassButtonStyle(tint: Theme.accent))
                            .disabled(isSigningIn)
                        }
                    }

                    SectionHeader(title: "Server Health")
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            InfoRow(title: "Server", value: serverInfo?.serverName ?? "Not connected")
                            InfoRow(title: "Version", value: serverInfo?.version ?? "-")
                            InfoRow(title: "Local", value: serverInfo?.localAddress ?? "-")
                            InfoRow(title: "WAN", value: serverInfo?.wanAddress ?? "-")
                        }
                    }

                    SectionHeader(title: "Library Stats")
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            InfoRow(title: "Movies", value: libraryCounts?.movieCount.map(String.init) ?? "-")
                            InfoRow(title: "Series", value: libraryCounts?.seriesCount.map(String.init) ?? "-")
                            InfoRow(title: "Episodes", value: libraryCounts?.episodeCount.map(String.init) ?? "-")
                        }
                    }

                    SectionHeader(title: "Connection Tests")
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Button {
                                Task { await testJellyfinConnection() }
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
                                Task { await testSeerrConnection() }
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

                    SectionHeader(title: "Admin Actions")
                    HStack(spacing: 12) {
                        Button("Scan Library") {
                            Task { await scanLibrary() }
                        }
                        .buttonStyle(GlassButtonStyle(tint: Theme.accentSecondary))
                        .disabled(!session.isAuthenticated)

                        Button("Restart Server") {
                            Task { await restartServer() }
                        }
                        .buttonStyle(GlassButtonStyle(tint: Color.white.opacity(0.2)))
                        .disabled(!session.isAuthenticated)
                    }

                    Button("Sign Out") {
                        session.signOut()
                    }
                    .buttonStyle(GlassButtonStyle(tint: Color.white.opacity(0.2)))

                    SectionHeader(title: "Pending Requests")
                    GlassCard {
                        if requests.isEmpty {
                            Text("No pending requests")
                                .font(Theme.bodyFont(14))
                                .foregroundStyle(Theme.muted)
                        } else {
                            VStack(spacing: 16) {
                                ForEach(requests) { request in
                                    RequestRow(
                                        request: request,
                                        onApprove: { Task { await approveRequest(request) } },
                                        onDecline: { Task { await declineRequest(request) } }
                                    )
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
        .navigationTitle("Admin")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await refreshAdminData()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Something went wrong.")
        }
    }

    private func signIn() async {
        isSigningIn = true
        defer { isSigningIn = false }

        do {
            try await session.signIn(password: password)
            password = ""
            await refreshAdminData()
        } catch {
            showError(error)
        }
    }

    private func refreshAdminData() async {
        guard let jellyfin = session.jellyfinClient else { return }
        do {
            async let info = jellyfin.systemInfo()
            async let counts = jellyfin.libraryCounts()
            let (serverInfoResult, countsResult) = try await (info, counts)
            serverInfo = serverInfoResult
            libraryCounts = countsResult
        } catch {
            showError(error)
        }

        if let seerr = session.seerrClient {
            do {
                requests = try await seerr.requestQueue()
            } catch {
                showError(error)
            }
        }
    }

    private func scanLibrary() async {
        guard let jellyfin = session.jellyfinClient else { return }
        do {
            try await jellyfin.refreshLibrary()
        } catch {
            showError(error)
        }
    }

    private func restartServer() async {
        guard let jellyfin = session.jellyfinClient else { return }
        do {
            try await jellyfin.restartServer()
        } catch {
            showError(error)
        }
    }

    private func approveRequest(_ request: SeerrRequest) async {
        guard let seerr = session.seerrClient else { return }
        do {
            try await seerr.approveRequest(id: request.id)
            await refreshAdminData()
        } catch {
            showError(error)
        }
    }

    private func declineRequest(_ request: SeerrRequest) async {
        guard let seerr = session.seerrClient else { return }
        do {
            try await seerr.declineRequest(id: request.id)
            await refreshAdminData()
        } catch {
            showError(error)
        }
    }

    private func showError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
    }

    private func testJellyfinConnection() async {
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

    private func testSeerrConnection() async {
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

private struct InfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(Theme.bodyFont(13))
                .foregroundStyle(Theme.muted)
            Spacer()
            Text(value)
                .font(Theme.bodyFont(14))
                .foregroundStyle(.white)
        }
    }
}

private struct RequestRow: View {
    let request: SeerrRequest
    let onApprove: () -> Void
    let onDecline: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(request.media?.displayTitle ?? "Request #\(request.id)")
                    .font(Theme.bodyFont(14))
                    .foregroundStyle(.white)
                Text((request.media?.mediaType ?? request.type)?.capitalized ?? "Unknown")
                    .font(Theme.bodyFont(12))
                    .foregroundStyle(Theme.muted)
            }

            Spacer()

            Button("Approve", action: onApprove)
                .buttonStyle(GlassButtonStyle(tint: Theme.accent))

            Button("Deny", action: onDecline)
                .buttonStyle(GlassButtonStyle(tint: Color.white.opacity(0.2)))
        }
    }
}
