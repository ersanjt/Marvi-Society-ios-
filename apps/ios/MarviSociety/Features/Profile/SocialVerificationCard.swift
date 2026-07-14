import SwiftUI
import UIKit

struct SocialVerificationCard: View {
    @EnvironmentObject private var appState: AppState

    @State private var feedback = ""
    @State private var isSubmitting = false
    @State private var copied = false

    private var verification: SocialVerificationStatus? { appState.socialVerification }

    var body: some View {
        Group {
            if appState.isAuthenticated, appState.selectedRole == .creator {
                MarviCard {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionTitle(
                            title: appState.t(.socialVerifyTitle),
                            subtitle: appState.t(.socialVerifySub)
                        )

                        handleRow(label: "Instagram", value: appState.profile.handle)
                        handleRow(label: "TikTok", value: appState.profile.tiktokHandle)

                        if appState.profile.handle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            && appState.profile.tiktokHandle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(appState.t(.socialSetupSub))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(MarviColor.gold)
                        } else if let verification {
                            statusBadge(for: verification.state)

                            if let code = verification.code, verification.state != .verified {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(appState.t(.socialVerifyCodeLabel))
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(MarviColor.muted)

                                    Text(code)
                                        .font(.title2.weight(.black))
                                        .foregroundStyle(MarviColor.rose)
                                        .textSelection(.enabled)

                                    Text(verification.dmMessage)
                                        .font(.caption)
                                        .foregroundStyle(MarviColor.graphite)
                                        .textSelection(.enabled)

                                    HStack(spacing: 10) {
                                        Button {
                                            UIPasteboard.general.string = verification.dmMessage
                                            copied = true
                                        } label: {
                                            Label(
                                                copied ? appState.t(.ok) : appState.t(.socialVerifyCopyCode),
                                                systemImage: copied ? "checkmark" : "doc.on.doc"
                                            )
                                            .font(.caption.weight(.bold))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundStyle(MarviColor.ink)
                                        .background(MarviColor.panelElevated)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                                        Button {
                                            openMarviInstagram(handle: verification.marviInstagramHandle)
                                        } label: {
                                            Label(appState.t(.socialVerifyOpenInstagram), systemImage: "paperplane.fill")
                                                .font(.caption.weight(.bold))
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 10)
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundStyle(.white)
                                        .background(MarviGradient.brand)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    }

                                    if verification.state == .pending {
                                        Button {
                                            Task {
                                                isSubmitting = true
                                                feedback = ""
                                                if let error = await appState.submitSocialVerificationSent() {
                                                    feedback = error
                                                }
                                                isSubmitting = false
                                            }
                                        } label: {
                                            Label(
                                                isSubmitting ? appState.t(.saving) : appState.t(.socialVerifySentBtn),
                                                systemImage: "checkmark.message.fill"
                                            )
                                            .font(.subheadline.weight(.bold))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundStyle(MarviColor.rose)
                                        .background(MarviColor.rose.opacity(0.12))
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        .disabled(isSubmitting)
                                    }
                                }
                            }

                            if !feedback.isEmpty {
                                Text(feedback)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(MarviColor.tomato)
                            }
                        }
                    }
                }
                .task {
                    await appState.loadSocialVerification()
                }
            }
        }
    }

    @ViewBuilder
    private func handleRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption.weight(.bold))
                .foregroundStyle(MarviColor.muted)
            Spacer()
            Text(value.isEmpty ? "—" : "@\(value.replacingOccurrences(of: "@", with: ""))")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MarviColor.ink)
        }
    }

    @ViewBuilder
    private func statusBadge(for state: SocialVerificationState) -> some View {
        let (text, icon, tint): (String, String, Color) = switch state {
        case .needsHandles:
            (appState.t(.socialSetupSub), "person.crop.circle.badge.exclamationmark", MarviColor.gold)
        case .pending:
            (appState.t(.socialVerifyPending), "hourglass", MarviColor.gold)
        case .submitted:
            (appState.t(.socialVerifySubmitted), "paperplane.circle.fill", MarviColor.blue)
        case .verified:
            (appState.t(.socialVerifyVerified), "checkmark.seal.fill", MarviColor.emerald)
        }

        Label(text, systemImage: icon)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(tint)
    }

    private func openMarviInstagram(handle: String) {
        if let url = URL(string: "https://instagram.com/\(handle)") {
            UIApplication.shared.open(url)
        }
    }
}
