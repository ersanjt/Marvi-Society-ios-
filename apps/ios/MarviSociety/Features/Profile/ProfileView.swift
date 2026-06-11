import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isShowingSignOutConfirmation = false
    @State private var isSavingProfile = false
    @State private var isSigningOut = false
    @State private var saveSuccessMessage: String?

    private var managementTitle: String {
        switch appState.selectedRole {
        case .creator: "Management"
        case .venue: "Venue studio"
        case .admin: "Admin console"
        }
    }

    var body: some View {
        NavigationStack {
            MarviScreen {
                ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 16) {
                        PremiumProfileHeader(
                            profile: appState.profile,
                            managementTitle: managementTitle,
                            onManagement: {
                                withAnimation {
                                    proxy.scrollTo("workspace-section", anchor: .center)
                                }
                                if appState.allowedRoles.contains(.admin) {
                                    appState.switchWorkspace(to: .admin)
                                }
                            }
                        )

                        MarviCard {
                            HStack(spacing: 20) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(appState.profile.audienceLabel.replacingOccurrences(of: " audience", with: ""))
                                        .font(.system(size: 36, weight: .bold, design: .rounded))
                                        .foregroundStyle(MarviColor.ink)
                                    Text("Followers")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(MarviColor.muted)
                                }

                                Spacer()

                                ProfileHealthRing(score: appState.profile.score, label: "Profile Health")
                            }
                        }

                        MarviCard {
                            VStack(alignment: .leading, spacing: 12) {
                                SectionTitle(
                                    title: "Workspace",
                                    subtitle: appState.accountRole == .admin
                                        ? "Admin access enabled on this account."
                                        : "Switch between creator, venue, and admin tools."
                                )

                                WorkspaceRolePicker(
                                    roles: UserRole.sortedWorkspaces(appState.allowedRoles),
                                    selected: $appState.selectedRole
                                )

                                Text(appState.selectedRole.description)
                                    .font(.subheadline)
                                    .foregroundStyle(MarviColor.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .id("workspace-section")

                        if appState.allowedRoles.contains(.admin) {
                            MarviCard {
                                VStack(alignment: .leading, spacing: 14) {
                                    SectionTitle(
                                        title: "Admin console",
                                        subtitle: "Review creator applications, campaigns, and proof."
                                    )

                                    HStack(spacing: 12) {
                                        AdminQuickStat(
                                            value: "\(appState.openAdminTasks.count)",
                                            label: "Open tasks",
                                            tint: MarviColor.tomato
                                        )
                                        AdminQuickStat(
                                            value: "\(appState.offers.count)",
                                            label: "Live offers",
                                            tint: MarviColor.emerald
                                        )
                                    }

                                    Button {
                                        appState.switchWorkspace(to: .admin)
                                    } label: {
                                        Label("Open admin console", systemImage: "checkmark.shield.fill")
                                            .font(.subheadline.weight(.bold))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 13)
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(.white)
                                    .background(MarviGradient.brand)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                            }
                        }

                        MarviCard {
                            VStack(alignment: .leading, spacing: 14) {
                                SectionTitle(title: "Creator signals", subtitle: "Used for invitation matching.")

                                HStack(spacing: 10) {
                                    ScoreTile(value: "\(appState.profile.score)", label: "Score", icon: "star.fill", tint: MarviColor.gold)
                                    ScoreTile(value: appState.profile.proofRate, label: "Delivery", icon: "checkmark.seal.fill", tint: MarviColor.emerald)
                                }
                            }
                        }

                        if !appState.strikes.isEmpty {
                            MarviCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    SectionTitle(title: "Strike history", subtitle: "Policy violations affect matching priority.")

                                    ForEach(appState.strikes) { strike in
                                        HStack(alignment: .top, spacing: 10) {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .foregroundStyle(MarviColor.tomato)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(strike.reason)
                                                    .font(.subheadline.weight(.semibold))
                                                Text("\(strike.severity.capitalized) · \(strike.createdAtLabel)")
                                                    .font(.caption)
                                                    .foregroundStyle(MarviColor.muted)
                                            }
                                        }
                                    }
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
                                SectionTitle(title: "Social accounts", subtitle: "Linked profiles for verification and proof tracking.")

                                MarviTextField(placeholder: "Display name", text: $appState.profile.name)
                                MarviTextField(placeholder: "City", text: $appState.profile.city)
                                MarviTextField(placeholder: "Instagram handle", text: $appState.profile.handle, autocapitalization: .never)
                                MarviTextField(placeholder: "TikTok handle", text: $appState.profile.tiktokHandle, autocapitalization: .never)

                                if let instagramURL = socialURL(platform: "instagram", handle: appState.profile.handle) {
                                    Link(destination: instagramURL) {
                                        Label("Open Instagram profile", systemImage: "camera")
                                            .font(.caption.weight(.bold))
                                    }
                                }

                                if let tiktokURL = socialURL(platform: "tiktok", handle: appState.profile.tiktokHandle) {
                                    Link(destination: tiktokURL) {
                                        Label("Open TikTok profile", systemImage: "music.note")
                                            .font(.caption.weight(.bold))
                                    }
                                }

                                if let saveSuccessMessage {
                                    Label(saveSuccessMessage, systemImage: "checkmark.circle.fill")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(MarviColor.emerald)
                                }

                                if appState.isAuthenticated {
                                    Button {
                                        Task {
                                            isSavingProfile = true
                                            saveSuccessMessage = nil
                                            await appState.saveProfileToServer()
                                            isSavingProfile = false
                                            if appState.lastSyncError == nil {
                                                saveSuccessMessage = "Profile saved to your account."
                                            }
                                        }
                                    } label: {
                                        Label(
                                            isSavingProfile ? "Saving…" : "Save to account",
                                            systemImage: "icloud.and.arrow.up"
                                        )
                                        .font(.subheadline.weight(.bold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(MarviColor.emerald)
                                    .background(MarviColor.emerald.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    .disabled(isSavingProfile || appState.isSyncing)
                                }
                            }
                        }

                        MarviCard {
                            VStack(alignment: .leading, spacing: 12) {
                                SectionTitle(title: "Application checklist", subtitle: "\(completedChecklistSteps) of 6 steps complete")
                                ChecklistRow(title: "Instagram connected", isDone: !appState.profile.handle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                ChecklistRow(title: "City verified", isDone: !appState.profile.city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                ChecklistRow(title: "Niche selected", isDone: !appState.profile.niches.isEmpty)
                                ChecklistRow(title: "Audience reviewed", isDone: appState.profile.score > 0)
                                ChecklistRow(title: "Creator references", isDone: appState.profile.completedApplicationSteps >= 5)
                                ChecklistRow(title: "Agreement signed", isDone: appState.profile.status == .approved)
                            }
                        }

                        MarviCard {
                            VStack(alignment: .leading, spacing: 12) {
                                SectionTitle(title: "Account")

                                HStack {
                                    Label(
                                        appState.isAuthenticated ? "Signed in" : "Not signed in",
                                        systemImage: appState.isAuthenticated ? "checkmark.seal.fill" : "person.crop.circle.badge.exclamationmark"
                                    )
                                    .font(.subheadline.weight(.semibold))
                                    Spacer()
                                    if appState.isSyncing {
                                        ProgressView().tint(MarviColor.rose)
                                    }
                                }

                                Button {
                                    Task { await appState.refreshFromServer() }
                                } label: {
                                    Label("Sync from server", systemImage: "arrow.triangle.2.circlepath")
                                        .font(.subheadline.weight(.bold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(MarviColor.emerald)
                                .background(MarviColor.emerald.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .disabled(appState.isSyncing)

                                if let error = appState.lastSyncError {
                                    Text(error)
                                        .font(.caption)
                                        .foregroundStyle(MarviColor.tomato)
                                }

                                if appState.isAuthenticated {
                                    Button(role: .destructive) {
                                        isShowingSignOutConfirmation = true
                                    } label: {
                                        Label(
                                            isSigningOut ? "Signing out…" : "Sign out",
                                            systemImage: "rectangle.portrait.and.arrow.right"
                                        )
                                        .font(.subheadline.weight(.bold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(MarviColor.tomato)
                                    .background(MarviColor.tomato.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    .disabled(isSigningOut || appState.isSyncing)
                                }
                            }
                        }

                        #if DEBUG
                        MarviCard {
                            VStack(alignment: .leading, spacing: 8) {
                                SectionTitle(title: "Developer", subtitle: "Mode: \(appState.backendLabel)")
                                Text("Debug builds only.")
                                    .font(.caption)
                                    .foregroundStyle(MarviColor.muted)
                            }
                        }
                        #endif

                        MarviCard {
                            VStack(alignment: .leading, spacing: 12) {
                                SectionTitle(title: "Legal & account", subtitle: "Policies required for App Store review.")

                                Link(destination: AppLinks.privacyPolicy) {
                                    Label("Privacy Policy", systemImage: "hand.raised")
                                }
                                Link(destination: AppLinks.termsOfService) {
                                    Label("Terms of Service", systemImage: "doc.text")
                                }
                                Link(destination: AppLinks.communityGuidelines) {
                                    Label("Community Guidelines", systemImage: "shield.lefthalf.filled")
                                }
                                Link(destination: AppLinks.support) {
                                    Label("Help & support", systemImage: "questionmark.circle")
                                }
                                Link(destination: AppLinks.deleteAccount) {
                                    Label("Delete account", systemImage: "person.crop.circle.badge.minus")
                                }
                                Link(destination: AppLinks.supportEmail) {
                                    Label("Email support", systemImage: "envelope")
                                }
                                Link(destination: URL(string: "mailto:support@marvisociety.com?subject=Safety%20report")!) {
                                    Label("Report a safety issue", systemImage: "exclamationmark.bubble")
                                }
                            }
                        }

                        MarviCard {
                            VStack(alignment: .leading, spacing: 14) {
                                SectionTitle(title: "Settings", subtitle: "Preferences saved on this device.")

                                Toggle("Push notifications", isOn: $appState.pushNotificationsEnabled)
                                Toggle("Proof deadline reminders", isOn: $appState.proofRemindersEnabled)
                                Toggle("Auto-save proof links", isOn: $appState.autoSaveProofLinks)
                            }
                        }
                    }
                    .padding(16)
                }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .task {
                await appState.syncAllowedRoles()
            }
            .alert("Sign out?", isPresented: $isShowingSignOutConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Sign out", role: .destructive) {
                    Task {
                        isSigningOut = true
                        await appState.signOut()
                        isSigningOut = false
                    }
                }
            } message: {
                Text("You will return to onboarding and need to sign in again.")
            }
        }
    }

    private var completedChecklistSteps: Int {
        var count = 0
        if !appState.profile.handle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { count += 1 }
        if !appState.profile.city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { count += 1 }
        if !appState.profile.niches.isEmpty { count += 1 }
        if appState.profile.score > 0 { count += 1 }
        if appState.profile.completedApplicationSteps >= 5 { count += 1 }
        if appState.profile.status == .approved { count += 1 }
        return count
    }

    private func socialURL(platform: String, handle: String) -> URL? {
        let sanitized = handle.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "@", with: "")
        guard !sanitized.isEmpty else { return nil }
        return URL(string: "https://\(platform).com/\(sanitized)")
    }
}

private struct PremiumProfileHeader: View {
    let profile: CreatorProfile
    let managementTitle: String
    let onManagement: () -> Void

    private var initials: String {
        let fromName = profile.name.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined()
        if !fromName.isEmpty { return fromName.uppercased() }
        let fromHandle = profile.handle.replacingOccurrences(of: "@", with: "").prefix(2)
        return fromHandle.isEmpty ? "M" : String(fromHandle).uppercased()
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                MarviGradient.brandVertical
                    .frame(height: 120)

                SSAvatarRing(initials: initials, size: 96)
                    .offset(y: 48)
            }

            VStack(spacing: 10) {
                Text(profile.name.isEmpty ? "Member" : profile.name)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(MarviColor.ink)
                    .padding(.top, 56)

                Text(profile.niches.first ?? "Creator")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MarviColor.rose)

                Text(profile.handle.isEmpty ? "@" : profile.handle)
                    .font(.caption)
                    .foregroundStyle(MarviColor.muted)

                StatusPill(
                    text: profile.status.rawValue,
                    tint: statusTint(for: profile.status),
                    systemImage: statusIcon(for: profile.status)
                )

                SSManagementButton(title: managementTitle, action: onManagement)
                    .padding(.horizontal, 4)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            .background(MarviColor.panel)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(MarviColor.border, lineWidth: 1)
        )
    }

    private func statusTint(for status: MembershipStatus) -> Color {
        switch status {
        case .approved: MarviColor.emerald
        case .underReview: MarviColor.gold
        case .paused: MarviColor.tomato
        }
    }

    private func statusIcon(for status: MembershipStatus) -> String {
        switch status {
        case .approved: "checkmark.seal"
        case .underReview: "hourglass"
        case .paused: "pause.circle"
        }
    }
}

private struct AdminQuickStat: View {
    let value: String
    let label: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(tint)
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(MarviColor.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(tint.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
        .background(MarviColor.panelElevated)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
