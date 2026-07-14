import SwiftUI

/// Blocks app access until a signed-in user redeems an invite code.
struct InviteRequiredView: View {
    @EnvironmentObject private var appState: AppState
    @State private var inviteCode = ""
    @State private var referralError = ""
    @State private var isValidating = false
    @State private var inviteAccepted = false

    var body: some View {
        ZStack {
            AccountGateBackdrop()

            VStack(spacing: 0) {
                Spacer(minLength: 40)

                VStack(alignment: .leading, spacing: 22) {
                    AccountGateHeader(
                        eyebrow: appState.t(.inviteStep),
                        title: appState.t(.inviteTitle),
                        subtitle: appState.t(.inviteSubtitle)
                    )

                    MarviTextField(
                        placeholder: appState.t(.invitePlaceholder),
                        text: $inviteCode,
                        autocapitalization: .characters
                    )

                    if inviteAccepted {
                        Label(appState.t(.inviteAccepted), systemImage: "checkmark.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(MarviColor.emerald)
                    }

                    if !referralError.isEmpty {
                        Label(referralError, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MarviColor.tomato)
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                Button {
                    Task { await redeem() }
                } label: {
                    Text(appState.t(.continueAction))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            canContinue
                                ? AnyShapeStyle(MarviGradient.brand)
                                : AnyShapeStyle(MarviColor.panelElevated)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!canContinue || isValidating)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)

            if isValidating {
                Color.black.opacity(0.45).ignoresSafeArea()
                ProgressView().tint(MarviColor.rose).scaleEffect(1.2)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if let pending = appState.pendingInviteCode, inviteCode.isEmpty {
                inviteCode = pending
            }
        }
    }

    private var canContinue: Bool {
        !inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func redeem() async {
        referralError = ""
        isValidating = true
        defer { isValidating = false }

        if let error = await appState.redeemReferralCode(inviteCode) {
            let lower = error.lowercased()
            if lower.contains("different email") {
                referralError = appState.t(.errInviteEmailMismatch)
            } else if lower.contains("invalid invite") {
                referralError = appState.t(.errInviteInvalid)
            } else {
                referralError = error
            }
            return
        }

        inviteAccepted = true
        appState.pendingInviteCode = nil
        await appState.syncAllowedRoles()
    }
}

/// Blocks creator access until Instagram or TikTok handle is saved.
struct SocialProfileSetupView: View {
    @EnvironmentObject private var appState: AppState
    @State private var instagramHandle = ""
    @State private var tiktokHandle = ""
    @State private var isSaving = false

    var body: some View {
        ZStack {
            AccountGateBackdrop()

            VStack(spacing: 0) {
                Spacer(minLength: 40)

                VStack(alignment: .leading, spacing: 22) {
                    AccountGateHeader(
                        eyebrow: appState.t(.socialAccounts),
                        title: appState.t(.socialSetupTitle),
                        subtitle: appState.t(.socialSetupSub)
                    )

                    MarviTextField(
                        placeholder: appState.t(.instagramPlaceholder),
                        text: $instagramHandle,
                        autocapitalization: .never
                    )

                    MarviTextField(
                        placeholder: appState.t(.tiktokHandleField),
                        text: $tiktokHandle,
                        autocapitalization: .never
                    )

                    if let error = appState.lastSyncError {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MarviColor.tomato)
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                Button {
                    Task { await save() }
                } label: {
                    Text(isSaving ? appState.t(.saving) : appState.t(.socialSetupContinue))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            isValid
                                ? AnyShapeStyle(MarviGradient.brand)
                                : AnyShapeStyle(MarviColor.panelElevated)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!isValid || isSaving)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)

            if isSaving {
                Color.black.opacity(0.45).ignoresSafeArea()
                ProgressView().tint(MarviColor.rose).scaleEffect(1.2)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            instagramHandle = appState.profile.handle
            tiktokHandle = appState.profile.tiktokHandle
        }
    }

    private var isValid: Bool {
        !instagramHandle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !tiktokHandle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() async {
        appState.dismissSyncError()
        isSaving = true
        defer { isSaving = false }

        let previousHandle = appState.profile.handle
        let previousTikTok = appState.profile.tiktokHandle
        appState.profile.handle = instagramHandle.trimmingCharacters(in: .whitespacesAndNewlines)
        appState.profile.tiktokHandle = tiktokHandle.trimmingCharacters(in: .whitespacesAndNewlines)
        let ok = await appState.saveProfileToServer()
        if !ok {
            appState.profile.handle = previousHandle
            appState.profile.tiktokHandle = previousTikTok
        }
    }
}

/// Blocks main app until an admin approves the membership.
struct ApprovalPendingView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isRefreshing = false

    private var isPaused: Bool { appState.profile.status == .paused }

    var body: some View {
        ZStack {
            AccountGateBackdrop()

            VStack(spacing: 0) {
                Spacer(minLength: 40)

                VStack(alignment: .leading, spacing: 22) {
                    AccountGateHeader(
                        eyebrow: appState.t(.member),
                        title: isPaused ? appState.t(.membershipPaused) : appState.t(.underReviewBanner),
                        subtitle: isPaused
                            ? appState.t(.pausedAdminBannerSub)
                            : appState.t(.underReviewBannerSub)
                    )

                    if let error = appState.lastSyncError {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MarviColor.tomato)
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                Button {
                    Task { await refresh() }
                } label: {
                    Text(isRefreshing ? appState.t(.pleaseWait) : appState.t(.syncFromServer))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AnyShapeStyle(MarviGradient.brand))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isRefreshing)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)

            if isRefreshing {
                Color.black.opacity(0.45).ignoresSafeArea()
                ProgressView().tint(MarviColor.rose).scaleEffect(1.2)
            }
        }
        .preferredColorScheme(.dark)
        .task {
            // Soft poll so approval unlocks without forcing a relaunch.
            while !Task.isCancelled, appState.needsAdminApproval {
                try? await Task.sleep(nanoseconds: 20_000_000_000)
                await appState.refreshFromServer()
            }
        }
    }

    private func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        await appState.refreshFromServer()
    }
}

private struct AccountGateBackdrop: View {
    var body: some View {
        LinearGradient(
            colors: [Color.black, MarviColor.ink.opacity(0.92), Color.black],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

private struct AccountGateHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(eyebrow)
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(MarviColor.rose)

            Text(title)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.white)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(MarviColor.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
