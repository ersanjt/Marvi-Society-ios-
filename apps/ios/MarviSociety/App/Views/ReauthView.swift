import SwiftUI

struct ReauthView: View {
    @EnvironmentObject private var appState: AppState
    @State private var email = ""
    @State private var password = ""
    @State private var isSigningIn = false

    var body: some View {
        NavigationStack {
            MarviScreen {
                VStack(spacing: 24) {
                    Spacer()

                    BrandMark(size: 64)

                    VStack(spacing: 8) {
                        Text("Welcome back")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(MarviColor.ink)
                        Text("Sign in to continue to Marvi Society.")
                            .font(.subheadline)
                            .foregroundStyle(MarviColor.muted)
                    }

                    MarviCard {
                        VStack(spacing: 12) {
                            MarviTextField(placeholder: "Email", text: $email, autocapitalization: .never)
                            SecureField("Password", text: $password)
                                .padding(12)
                                .foregroundStyle(MarviColor.ink)
                                .background(MarviColor.panelElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(MarviColor.border, lineWidth: 1)
                                )

                            PrimaryActionButton(
                                title: isSigningIn ? "Signing in…" : "Sign in",
                                systemImage: "arrow.right.circle",
                                isDisabled: email.isEmpty || password.isEmpty || isSigningIn
                            ) {
                                Task {
                                    isSigningIn = true
                                    await appState.signInWithEmail(
                                        email.trimmingCharacters(in: .whitespacesAndNewlines),
                                        password: password,
                                        metadata: [:]
                                    )
                                    if appState.isAuthenticated {
                                        appState.needsReauthentication = false
                                        appState.dismissSyncError()
                                    }
                                    isSigningIn = false
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    if let error = appState.lastSyncError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(MarviColor.tomato)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    Spacer()
                }
            }
        }
    }
}
