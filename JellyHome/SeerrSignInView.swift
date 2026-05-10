import SwiftUI

struct SeerrSignInView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    @State private var password: String = ""
    @State private var isSigningIn = false
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        NavigationStack {
            ZStack {
                LiquidBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Sign In to Seerr")
                            .font(Theme.titleFont(28))
                            .foregroundStyle(.white)

                        GlassCard {
                            VStack(spacing: 16) {
                                LabeledTextField(title: "Seerr/Jellyseerr URL", text: $session.seerrBaseURL, keyboard: .URL)
                                LabeledTextField(title: "Username", text: $session.username)
                                LabeledSecureField(title: "Password", text: $password)

                                Button {
                                    Task { await signIn() }
                                } label: {
                                    HStack(spacing: 10) {
                                        if isSigningIn {
                                            ProgressView().tint(.white)
                                        }
                                        Text("Connect")
                                    }
                                }
                                .buttonStyle(GlassButtonStyle(tint: Theme.accent))
                                .disabled(isSigningIn)
                            }
                        }

                        if let warning = session.lastSignInWarning {
                            Text(warning)
                                .font(Theme.bodyFont(12))
                                .foregroundStyle(Theme.muted)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Seerr Login")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Login Failed", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Could not sign in to Seerr.")
            }
        }
    }

    private func signIn() async {
        isSigningIn = true
        defer { isSigningIn = false }

        do {
            try await session.signInSeerr(password: password)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
