import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isShowingSignOutConfirmation = false
    @State private var isShowingPauseConfirmation = false
    @State private var isShowingDeleteConfirmation = false
    @State private var deleteConfirmationText = ""
    @State private var isManagingAccount = false
    @State private var accountActionMessage: String?
    @State private var isSavingProfile = false
    @State private var isSigningOut = false
    @State private var saveSuccessMessage: String?
    @State private var nichesText = ""
    @State private var languagesText = ""

    private var managementTitle: String {
        switch appState.selectedRole {
        case .creator: appState.t(.management)
        case .venue: appState.t(.venueStudio)
        case .admin: appState.t(.adminConsole)
        }
    }

    private var languageSelection: Binding<AppLanguage> {
        Binding(
            get: { appState.preferredLanguage },
            set: { appState.setPreferredLanguage($0, manual: true) }
        )
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
                            }
                        )

                        MarviCard {
                            HStack(spacing: 20) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(appState.profile.audienceLabel.replacingOccurrences(of: " audience", with: ""))
                                        .font(.system(size: 36, weight: .bold, design: .rounded))
                                        .foregroundStyle(MarviColor.ink)
                                    Text(appState.t(.followers))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(MarviColor.muted)
                                }

                                Spacer()

                                ProfileHealthRing(score: appState.profile.score, label: appState.t(.profileHealth))
                            }
                        }

                        MarviCard {
                            VStack(alignment: .leading, spacing: 12) {
                                SectionTitle(
                                    title: appState.t(.workspace),
                                    subtitle: appState.accountRole == .admin
                                        ? appState.t(.workspaceAdminSub)
                                        : appState.t(.workspaceSwitchSub)
                                )

                                WorkspaceRolePicker(
                                    roles: UserRole.sortedWorkspaces(appState.allowedRoles),
                                    selected: $appState.selectedRole,
                                    onSelect: { role in
                                        appState.switchWorkspace(to: role)
                                        if role == .admin {
                                            Task { await appState.openAdminConsole() }
                                        }
                                    }
                                )

                                Text(appState.selectedRole.description)
                                    .font(.subheadline)
                                    .foregroundStyle(MarviColor.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .id("workspace-section")

                        if appState.accountRole == .admin || appState.allowedRoles.contains(.admin) {
                            MarviCard {
                                VStack(alignment: .leading, spacing: 14) {
                                    SectionTitle(
                                        title: appState.t(.adminConsole),
                                        subtitle: appState.t(.adminConsoleSub)
                                    )

                                    HStack(spacing: 12) {
                                        AdminQuickStat(
                                            value: "\(appState.openAdminTasks.count)",
                                            label: appState.t(.openTasks),
                                            tint: MarviColor.tomato
                                        )
                                        AdminQuickStat(
                                            value: "\(appState.offers.count)",
                                            label: appState.t(.liveOffers),
                                            tint: MarviColor.emerald
                                        )
                                    }

                                    Button {
                                        Task { await appState.openAdminConsole() }
                                    } label: {
                                        Label(appState.t(.openAdminConsole), systemImage: "checkmark.shield.fill")
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
                                SectionTitle(title: appState.t(.creatorSignals), subtitle: appState.t(.creatorSignalsSub))

                                HStack(spacing: 10) {
                                    ScoreTile(value: "\(appState.profile.score)", label: appState.t(.scoreLabel), icon: "star.fill", tint: MarviColor.gold)
                                    ScoreTile(value: appState.profile.proofRate, label: appState.t(.deliveryLabel), icon: "checkmark.seal.fill", tint: MarviColor.emerald)
                                }
                            }
                        }

                        if !appState.strikes.isEmpty {
                            MarviCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    SectionTitle(title: appState.t(.strikeHistory), subtitle: appState.t(.strikeHistorySub))

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
                                SectionTitle(title: appState.t(.socialAccounts), subtitle: appState.t(.socialAccountsSub))

                                MarviTextField(placeholder: appState.t(.displayName), text: $appState.profile.name)
                                MarviTextField(placeholder: appState.t(.bio), text: $appState.profile.bio)
                                MarviTextField(placeholder: appState.t(.cityField), text: $appState.profile.city)
                                MarviTextField(placeholder: appState.t(.instagramPlaceholder), text: $appState.profile.handle, autocapitalization: .never)
                                MarviTextField(placeholder: appState.t(.tiktokHandleField), text: $appState.profile.tiktokHandle, autocapitalization: .never)
                                MarviTextField(
                                    placeholder: appState.t(.nichesComma),
                                    text: $nichesText,
                                    autocapitalization: .words
                                )
                                MarviTextField(
                                    placeholder: appState.t(.languagesComma),
                                    text: $languagesText,
                                    autocapitalization: .words
                                )

                                if let instagramURL = socialURL(platform: "instagram", handle: appState.profile.handle) {
                                    Link(destination: instagramURL) {
                                        Label(appState.t(.openInstagram), systemImage: "camera")
                                            .font(.caption.weight(.bold))
                                    }
                                }

                                if let tiktokURL = socialURL(platform: "tiktok", handle: appState.profile.tiktokHandle) {
                                    Link(destination: tiktokURL) {
                                        Label(appState.t(.openTiktok), systemImage: "music.note")
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
                                            appState.profile.niches = nichesText
                                                .split(separator: ",")
                                                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                                                .filter { !$0.isEmpty }
                                            appState.profile.languages = languagesText
                                                .split(separator: ",")
                                                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                                                .filter { !$0.isEmpty }
                                            await appState.saveProfileToServer()
                                            isSavingProfile = false
                                            if appState.lastSyncError == nil {
                                                saveSuccessMessage = appState.t(.profileSavedSuccess)
                                            }
                                        }
                                    } label: {
                                        Label(
                                            isSavingProfile ? appState.t(.saving) : appState.t(.saveToAccount),
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
                                SectionTitle(
                                    title: appState.t(.applicationChecklist),
                                    subtitle: "\(completedChecklistSteps) \(appState.t(.checklistProgress))"
                                )
                                ChecklistRow(title: appState.t(.instagramConnected), isDone: !appState.profile.handle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                ChecklistRow(title: appState.t(.cityVerified), isDone: !appState.profile.city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                ChecklistRow(title: appState.t(.nicheSelected), isDone: !appState.profile.niches.isEmpty)
                                ChecklistRow(title: appState.t(.audienceReviewed), isDone: appState.profile.score > 0)
                                ChecklistRow(title: appState.t(.creatorReferences), isDone: !appState.profile.bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                ChecklistRow(title: appState.t(.agreementSigned), isDone: appState.profile.status == .approved)
                            }
                        }

                        MarviCard {
                            VStack(alignment: .leading, spacing: 12) {
                                SectionTitle(title: appState.t(.accountSection))

                                HStack {
                                    Label(
                                        appState.isAuthenticated ? appState.t(.signedIn) : appState.t(.notSignedIn),
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
                                    Label(appState.t(.syncFromServer), systemImage: "arrow.triangle.2.circlepath")
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
                                            isSigningOut ? appState.t(.signingOut) : appState.t(.signOut),
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
                                SectionTitle(title: appState.t(.developer), subtitle: "Mode: \(appState.backendLabel)")
                                Text(appState.t(.debugBuildsOnly))
                                    .font(.caption)
                                    .foregroundStyle(MarviColor.muted)
                            }
                        }
                        #endif

                        MarviCard {
                            VStack(alignment: .leading, spacing: 12) {
                                SectionTitle(
                                    title: appState.t(.accountSection),
                                    subtitle: appState.t(.accountSectionSub)
                                )

                                if appState.profile.status == .paused, appState.accountPausedBySelf {
                                    Text(appState.t(.pausedSelfBannerSub))
                                        .font(.caption)
                                        .foregroundStyle(MarviColor.muted)

                                    Button {
                                        Task {
                                            isManagingAccount = true
                                            accountActionMessage = await appState.reactivateAccount()
                                            isManagingAccount = false
                                        }
                                    } label: {
                                        Label(
                                            isManagingAccount ? appState.t(.reactivating) : appState.t(.reactivateAccount),
                                            systemImage: "play.circle"
                                        )
                                        .font(.subheadline.weight(.bold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(MarviColor.emerald)
                                    .background(MarviColor.emerald.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    .disabled(isManagingAccount || appState.isSyncing)
                                } else if appState.isAuthenticated {
                                    Text(appState.t(.pauseAccountSub))
                                        .font(.caption)
                                        .foregroundStyle(MarviColor.muted)

                                    Button {
                                        isShowingPauseConfirmation = true
                                    } label: {
                                        Label(appState.t(.pauseAccount), systemImage: "pause.circle")
                                            .font(.subheadline.weight(.bold))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(MarviColor.gold)
                                    .background(MarviColor.gold.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    .disabled(isManagingAccount || appState.isSyncing)

                                    Button(role: .destructive) {
                                        deleteConfirmationText = ""
                                        isShowingDeleteConfirmation = true
                                    } label: {
                                        Label(appState.t(.deleteAccountForever), systemImage: "trash")
                                            .font(.subheadline.weight(.bold))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(MarviColor.tomato)
                                    .background(MarviColor.tomato.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    .disabled(isManagingAccount || appState.isSyncing)
                                }

                                if let accountActionMessage {
                                    Text(accountActionMessage)
                                        .font(.caption)
                                        .foregroundStyle(MarviColor.emerald)
                                }
                            }
                        }

                        MarviCard {
                            VStack(alignment: .leading, spacing: 12) {
                                SectionTitle(title: appState.t(.legalSection), subtitle: appState.t(.legalSectionSub))

                                Link(destination: AppLinks.privacyPolicy) {
                                    Label(appState.t(.privacyPolicy), systemImage: "hand.raised")
                                }
                                Link(destination: AppLinks.termsOfService) {
                                    Label(appState.t(.termsOfService), systemImage: "doc.text")
                                }
                                Link(destination: AppLinks.communityGuidelines) {
                                    Label(appState.t(.communityGuidelines), systemImage: "shield.lefthalf.filled")
                                }
                                Link(destination: AppLinks.support) {
                                    Label(appState.t(.helpSupport), systemImage: "questionmark.circle")
                                }
                                Link(destination: AppLinks.deleteAccount) {
                                    Label(appState.t(.deleteOnWeb), systemImage: "safari")
                                }
                                Link(destination: AppLinks.supportEmail) {
                                    Label(appState.t(.emailSupport), systemImage: "envelope")
                                }
                                Link(destination: AppLinks.safetyReportEmail) {
                                    Label(appState.t(.reportSafety), systemImage: "exclamationmark.bubble")
                                }
                            }
                        }

                        if !appState.inboxMessages.isEmpty {
                            MarviCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    SectionTitle(
                                        title: MarviL10n.t(.inboxTitle, language: appState.preferredLanguage),
                                        subtitle: "\(appState.unreadInboxCount) \(appState.t(.unreadSuffix))"
                                    )
                                    NavigationLink {
                                        InboxView()
                                    } label: {
                                        Label(
                                            MarviL10n.t(.inboxTitle, language: appState.preferredLanguage),
                                            systemImage: "bell.badge"
                                        )
                                        .font(.subheadline.weight(.bold))
                                    }
                                }
                            }
                        }

                        MarviCard {
                            VStack(alignment: .leading, spacing: 14) {
                                SectionTitle(title: appState.t(.settingsSection), subtitle: appState.t(.settingsSub))

                                Picker(appState.t(.languageLabel), selection: languageSelection) {
                                    ForEach(AppLanguage.allCases) { language in
                                        Text(language.label).tag(language)
                                    }
                                }
                                .pickerStyle(.segmented)

                                Toggle(appState.t(.pushNotifications), isOn: $appState.pushNotificationsEnabled)
                                Toggle(appState.t(.proofReminders), isOn: $appState.proofRemindersEnabled)
                                Toggle(appState.t(.autoSaveProofLinks), isOn: $appState.autoSaveProofLinks)
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
                nichesText = appState.profile.niches.joined(separator: ", ")
                languagesText = appState.profile.languages.joined(separator: ", ")
            }
            .alert(appState.t(.pauseConfirmTitle), isPresented: $isShowingPauseConfirmation) {
                Button(appState.t(.cancel), role: .cancel) {}
                Button(appState.t(.closeAccountBtn), role: .destructive) {
                    Task {
                        isManagingAccount = true
                        accountActionMessage = nil
                        if let error = await appState.pauseAccount() {
                            accountActionMessage = error
                        } else {
                            accountActionMessage = appState.t(.accountPausedMessage)
                        }
                        isManagingAccount = false
                    }
                }
            } message: {
                Text(appState.t(.pauseConfirmMessage))
            }
            .alert(appState.t(.deleteConfirmTitle), isPresented: $isShowingDeleteConfirmation) {
                TextField(appState.t(.typeDeleteHint), text: $deleteConfirmationText)
                    .textInputAutocapitalization(.characters)
                Button(appState.t(.cancel), role: .cancel) {
                    deleteConfirmationText = ""
                }
                Button(appState.t(.deleteForeverBtn), role: .destructive) {
                    let expected = appState.t(.deleteConfirmWord)
                    guard deleteConfirmationText.trimmingCharacters(in: .whitespacesAndNewlines)
                        .compare(expected, options: .caseInsensitive) == .orderedSame else {
                        accountActionMessage = appState.t(.errTypeDelete)
                        return
                    }
                    Task {
                        isManagingAccount = true
                        accountActionMessage = await appState.deleteAccountPermanently()
                        isManagingAccount = false
                        deleteConfirmationText = ""
                    }
                }
            } message: {
                Text(appState.t(.deleteConfirmMessage))
            }
            .alert(appState.t(.signOutTitle), isPresented: $isShowingSignOutConfirmation) {
                Button(appState.t(.cancel), role: .cancel) {}
                Button(appState.t(.signOut), role: .destructive) {
                    Task {
                        isSigningOut = true
                        await appState.signOut()
                        isSigningOut = false
                    }
                }
            } message: {
                Text(appState.t(.signOutMessage))
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
    @EnvironmentObject private var appState: AppState
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
                Text(profile.name.isEmpty ? appState.t(.member) : profile.name)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(MarviColor.ink)
                    .padding(.top, 56)

                Text(profile.niches.first ?? appState.t(.creator))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MarviColor.rose)

                Text(profile.handle.isEmpty ? "@" : profile.handle)
                    .font(.caption)
                    .foregroundStyle(MarviColor.muted)

                StatusPill(
                    text: profile.status.label(for: appState.preferredLanguage),
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
