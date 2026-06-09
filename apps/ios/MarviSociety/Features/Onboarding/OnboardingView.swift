import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedRole: UserRole = .creator
    @State private var instagramHandle = "@aylin.in.istanbul"
    @State private var city = "Istanbul"
    @State private var inviteCode = "MARVI-IST"

    var body: some View {
        NavigationStack {
            MarviScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        VStack(alignment: .leading, spacing: 18) {
                            BrandMark(size: 64)

                            VStack(alignment: .leading, spacing: 10) {
                                Text("Marvi Society")
                                    .font(.system(size: 44, weight: .bold, design: .serif))
                                    .foregroundStyle(MarviColor.ink)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.78)

                                Text("Istanbul's private creator and venue collaboration club.")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(MarviColor.graphite)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.top, 18)

                        HStack(spacing: 10) {
                            MetricTile(value: "42", label: "venues", icon: "building.2", tint: MarviColor.emerald)
                            MetricTile(value: "128", label: "creators", icon: "person.2", tint: MarviColor.aubergine)
                            MetricTile(value: "96%", label: "proof", icon: "checkmark.seal", tint: MarviColor.blue)
                        }

                        VStack(spacing: 12) {
                            OnboardingSignal(icon: "checkmark.seal", title: "Approved members", subtitle: "Creator applications stay under review until admin approval.")
                            OnboardingSignal(icon: "calendar.badge.plus", title: "Curated invitations", subtitle: "Venues define value, slots, timing, deliverables, and dress code.")
                            OnboardingSignal(icon: "tray.and.arrow.up", title: "Proof workflow", subtitle: "Members submit links after attendance so operators can close the campaign.")
                        }

                        SectionTitle(title: "Choose your workspace")

                        VStack(spacing: 10) {
                            ForEach(UserRole.allCases) { role in
                                RoleOption(role: role, isSelected: selectedRole == role) {
                                    selectedRole = role
                                }
                            }
                        }

                        MarviCard {
                            VStack(alignment: .leading, spacing: 12) {
                                SectionTitle(title: "Quick setup", subtitle: "This is local demo data for the first build.")

                                TextField("Instagram handle", text: $instagramHandle)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .textFieldStyle(.roundedBorder)

                                TextField("City", text: $city)
                                    .textFieldStyle(.roundedBorder)

                                TextField("Invite code", text: $inviteCode)
                                    .textInputAutocapitalization(.characters)
                                    .autocorrectionDisabled()
                                    .textFieldStyle(.roundedBorder)
                            }
                        }

                        if !isSetupValid {
                            Label("Handle, city, and invite code are required.", systemImage: "exclamationmark.triangle")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(MarviColor.tomato)
                        }

                        PrimaryActionButton(
                            title: "Enter Marvi Society",
                            systemImage: "arrow.right.circle",
                            isDisabled: !isSetupValid
                        ) {
                            appState.profile.handle = instagramHandle
                            appState.profile.city = city
                            appState.completeOnboarding(role: selectedRole)
                        }
                    }
                    .padding(16)
                }
            }
        }
    }

    private var isSetupValid: Bool {
        !instagramHandle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private struct OnboardingSignal: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.headline.weight(.semibold))
                .foregroundStyle(MarviColor.emerald)
                .frame(width: 36, height: 36)
                .background(MarviColor.emerald.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(MarviColor.ink)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(MarviColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(12)
        .background(MarviColor.panel)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct RoleOption: View {
    let role: UserRole
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: role.icon)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(isSelected ? .white : MarviColor.emerald)
                    .frame(width: 40, height: 40)
                    .background(isSelected ? MarviColor.emerald : MarviColor.emerald.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(role.rawValue)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(MarviColor.ink)

                    Text(role.description)
                        .font(.caption)
                        .foregroundStyle(MarviColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.headline)
                    .foregroundStyle(isSelected ? MarviColor.emerald : MarviColor.muted)
            }
            .padding(14)
            .background(MarviColor.panel)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? MarviColor.emerald : Color.black.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
