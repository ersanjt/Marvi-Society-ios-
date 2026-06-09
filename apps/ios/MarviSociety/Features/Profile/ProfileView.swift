import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isShowingResetConfirmation = false

    var body: some View {
        NavigationStack {
            MarviScreen {
                ScrollView {
                    VStack(spacing: 16) {
                        BrandLockup(subtitle: "Member account")

                        ProfileHeader(profile: appState.profile)

                        MarviCard {
                            VStack(alignment: .leading, spacing: 12) {
                                SectionTitle(title: "Workspace")

                                Picker("Role", selection: $appState.selectedRole) {
                                    ForEach(UserRole.allCases) { role in
                                        Label(role.rawValue, systemImage: role.icon)
                                            .tag(role)
                                    }
                                }
                                .pickerStyle(.segmented)

                                Text(appState.selectedRole.description)
                                    .font(.subheadline)
                                    .foregroundStyle(MarviColor.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        MarviCard {
                            VStack(alignment: .leading, spacing: 14) {
                                SectionTitle(title: "Creator fit", subtitle: "Signals used for invitation matching.")

                                HStack(spacing: 10) {
                                    ScoreTile(value: "\(appState.profile.score)", label: "Score", icon: "star.fill", tint: MarviColor.gold)
                                    ScoreTile(value: appState.profile.audienceLabel, label: "Reach", icon: "person.3.fill", tint: MarviColor.blue)
                                }

                                HStack(spacing: 10) {
                                    ScoreTile(value: appState.profile.proofRate, label: "Delivery", icon: "checkmark.seal.fill", tint: MarviColor.emerald)
                                    ScoreTile(value: "Istanbul", label: "Market", icon: "location.fill", tint: MarviColor.tomato)
                                }
                            }
                        }

                        MarviCard {
                            VStack(alignment: .leading, spacing: 12) {
                                SectionTitle(title: "Niches")

                                FlowLayout(items: appState.profile.niches)
                            }
                        }

                        MarviCard {
                            VStack(alignment: .leading, spacing: 12) {
                                SectionTitle(title: "Languages")

                                FlowLayout(items: appState.profile.languages)
                            }
                        }

                        MarviCard {
                            VStack(alignment: .leading, spacing: 12) {
                                SectionTitle(title: "Application checklist", subtitle: "\(appState.profile.completedApplicationSteps) of 6 steps complete")
                                ChecklistRow(title: "Instagram connected", isDone: true)
                                ChecklistRow(title: "City verified", isDone: true)
                                ChecklistRow(title: "Niche selected", isDone: true)
                                ChecklistRow(title: "Audience reviewed", isDone: true)
                                ChecklistRow(title: "Creator references", isDone: false)
                                ChecklistRow(title: "Agreement signed", isDone: false)
                            }
                        }

                        MarviCard {
                            VStack(alignment: .leading, spacing: 14) {
                                SectionTitle(title: "Settings", subtitle: "Local prototype preferences are saved on this device.")

                                Toggle("Push notifications", isOn: $appState.pushNotificationsEnabled)
                                Toggle("Proof deadline reminders", isOn: $appState.proofRemindersEnabled)
                                Toggle("Auto-save proof links", isOn: $appState.autoSaveProofLinks)

                                Button(role: .destructive) {
                                    isShowingResetConfirmation = true
                                } label: {
                                    Label("Reset local demo", systemImage: "arrow.counterclockwise.circle")
                                        .font(.subheadline.weight(.bold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(MarviColor.tomato)
                                .background(MarviColor.tomato.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Profile")
            .alert("Reset Marvi Society?", isPresented: $isShowingResetConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    appState.resetDemoData()
                }
            } message: {
                Text("This clears local onboarding, bookings, campaigns, admin tasks, and proof submissions.")
            }
        }
    }
}

private struct ProfileHeader: View {
    let profile: CreatorProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                ZStack {
                    MarviColor.emerald
                    Text("AD")
                        .font(.title.weight(.bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    StatusPill(text: profile.status.rawValue, tint: MarviColor.emerald, systemImage: "checkmark.seal")

                    Text(profile.name)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(MarviColor.ink)

                    Text(profile.handle)
                        .font(.subheadline)
                        .foregroundStyle(MarviColor.muted)
                }

                Spacer()
            }

            Text(profile.bio)
                .font(.subheadline)
                .foregroundStyle(MarviColor.graphite)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(MarviColor.panel)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ScoreTile: View {
    let value: String
    let label: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(tint)

            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(MarviColor.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.78)

            Text(label)
                .font(.caption)
                .foregroundStyle(MarviColor.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(MarviColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct FlowLayout: View {
    let items: [String]

    var body: some View {
        HStack {
            ForEach(items, id: \.self) { item in
                StatusPill(text: item, tint: MarviColor.aubergine, systemImage: nil)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ChecklistRow: View {
    let title: String
    let isDone: Bool

    var body: some View {
        HStack {
            Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isDone ? MarviColor.emerald : MarviColor.muted)

            Text(title)
                .font(.subheadline)
                .foregroundStyle(MarviColor.graphite)

            Spacer()
        }
    }
}
