import SwiftUI

struct ReauthView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var appleSignIn = AppleSignInService()
    @StateObject private var googleSignIn = GoogleSignInService()
    @State private var email = ""
    @State private var password = ""
    @State private var isSigningIn = false
    @State private var showPasswordResetConfirmation = false

    private var lang: AppLanguage { appState.preferredLanguage }

    var body: some View {
        NavigationStack {
            MarviScreen {
                VStack(spacing: 24) {
                    Spacer()

                    BrandMark(size: 64)

                    VStack(spacing: 8) {
                        Text(appState.t(.welcomeBack))
                            .font(.title2.weight(.bold))
                            .foregroundStyle(MarviColor.ink)
                        Text(appState.t(.signInToContinue))
                            .font(.subheadline)
                            .foregroundStyle(MarviColor.muted)
                            .multilineTextAlignment(.center)
                    }

                    MarviCard {
                        VStack(spacing: 12) {
                            MarviTextField(placeholder: appState.t(.email), text: $email, autocapitalization: .never)
                            SecureField(appState.t(.password), text: $password)
                                .padding(12)
                                .foregroundStyle(MarviColor.ink)
                                .background(MarviColor.panelElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(MarviColor.border, lineWidth: 1)
                                )

                            PrimaryActionButton(
                                title: isSigningIn ? appState.t(.signingIn) : appState.t(.signIn),
                                systemImage: "arrow.right.circle",
                                isDisabled: email.isEmpty || password.isEmpty || isBusy
                            ) {
                                Task { await signInWithEmail() }
                            }

                            if APIConfig.appleSignInEnabled || APIConfig.googleSignInEnabled {
                                SocialDivider(label: appState.t(.orContinueWith))

                                if APIConfig.appleSignInEnabled {
                                    AppleSignInButton(
                                        title: appleSignIn.isSigningIn ? appState.t(.signingIn) : appState.t(.signInWithApple),
                                        isLoading: appleSignIn.isSigningIn,
                                        isDisabled: isBusy
                                    ) {
                                        Task { await signInWithApple() }
                                    }
                                }

                                if APIConfig.googleSignInEnabled {
                                    GoogleSignInButton(
                                        title: googleSignIn.isSigningIn ? appState.t(.signingIn) : appState.t(.signInWithGoogle),
                                        isLoading: googleSignIn.isSigningIn,
                                        isDisabled: isBusy
                                    ) {
                                        Task { await signInWithGoogle() }
                                    }
                                }
                            }

                            Button {
                                Task {
                                    await appState.requestPasswordReset(email: email)
                                    if appState.passwordResetMessage != nil {
                                        showPasswordResetConfirmation = true
                                    }
                                }
                            } label: {
                                Text(appState.t(.forgotPasswordEmail))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(MarviColor.muted)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                            .disabled(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isBusy)
                        }
                    }
                    .padding(.horizontal, 16)

                    if let error = appState.lastSyncError ?? googleSignIn.lastError {
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
        .alert(appState.t(.checkEmailTitle), isPresented: $showPasswordResetConfirmation) {
            Button(appState.t(.ok)) {
                appState.dismissPasswordResetMessage()
            }
        } message: {
            Text(appState.passwordResetMessage ?? appState.t(.passwordResetDefault))
            + Text("\n\n") + Text(appState.t(.passwordResetInstructions))
        }
    }

    private var isBusy: Bool {
        isSigningIn || appleSignIn.isSigningIn || googleSignIn.isSigningIn || appState.isSyncing
    }

    private func signInWithEmail() async {
        isSigningIn = true
        appState.dismissSyncError()
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

    private func signInWithGoogle() async {
        appState.dismissSyncError()
        await appState.signInWithGoogle(using: googleSignIn, metadata: [:])
        if appState.isAuthenticated {
            appState.needsReauthentication = false
            appState.dismissSyncError()
        }
    }

    private func signInWithApple() async {
        appState.dismissSyncError()
        await appState.signInWithApple(using: appleSignIn, metadata: [:])
        if appState.isAuthenticated {
            appState.needsReauthentication = false
            appState.dismissSyncError()
        }
    }
}
