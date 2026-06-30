import PhotosUI
import SwiftUI

private enum ProfileInsightTab: String, CaseIterable {
    case engagement
    case health

    func title(for language: AppLanguage) -> String {
        switch self {
        case .engagement:
            MarviL10n.t(.profileEngagement, language: language)
        case .health:
            MarviL10n.t(.profileHealth, language: language)
        }
    }
}

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
    @State private var selectedInsightTab: ProfileInsightTab = .engagement
    @State private var avatarPickerItem: PhotosPickerItem?
    @State private var coverPickerItem: PhotosPickerItem?
    @State private var inviteEmail = ""
    @State private var isSendingInvite = false
    @State private var inviteSuccessMessage: String?

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
                            VStack(alignment: .leading, spacing: 14) {
                                ProfileInsightPicker(
                                    selected: $selectedInsightTab,
                                    language: appState.preferredLanguage
                                )

                                if selectedInsightTab == .engagement {
                                    ProfileEngagementPanel(profile: appState.profile, followersLabel: appState.t(.followers))
                                } else {
                                    ProfileHealthPanel(profile: appState.profile, healthLabel: appState.t(.profileHealth))
                                }
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

                                HStack(spacing: 10) {
                                    PhotosPicker(selection: $avatarPickerItem, matching: .images) {
                                        Label(appState.t(.changeAvatar), systemImage: "person.crop.circle")
                                            .font(.caption.weight(.bold))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(MarviColor.rose)
                                    .background(MarviColor.rose.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                                    PhotosPicker(selection: $coverPickerItem, matching: .images) {
                                        Label(appState.t(.changeCover), systemImage: "photo")
                                            .font(.caption.weight(.bold))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(MarviColor.rose)
                                    .background(MarviColor.rose.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }

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
                                ChecklistRow(title: appState.t(.tiktokConnected), isDone: !appState.profile.tiktokHandle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                ChecklistRow(title: appState.t(.cityVerified), isDone: !appState.profile.city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                ChecklistRow(title: appState.t(.nicheSelected), isDone: !appState.profile.niches.isEmpty)
                                ChecklistRow(title: appState.t(.audienceReviewed), isDone: appState.profile.score > 0)
                                ChecklistRow(title: appState.t(.creatorReferences), isDone: !appState.profile.bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                ChecklistRow(title: appState.t(.agreementSigned), isDone: appState.profile.status == .approved)
                            }
                        }

                        if appState.isAuthenticated, appState.selectedRole == .creator {
                            MarviCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    SectionTitle(
                                        title: appState.t(.inviteFriends),
                                        subtitle: appState.t(.inviteFriendsSub)
                                    )

                                    MarviTextField(
                                        placeholder: appState.t(.inviteEmailPlaceholder),
                                        text: $inviteEmail,
                                        autocapitalization: .never
                                    )

                                    if let inviteSuccessMessage {
                                        Label(inviteSuccessMessage, systemImage: "checkmark.circle.fill")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(MarviColor.emerald)
                                    }

                                    Button {
                                        Task {
                                            isSendingInvite = true
                                            inviteSuccessMessage = nil
                                            if let error = await appState.sendCreatorInvite(email: inviteEmail) {
                                                _ = error
                                            } else {
                                                inviteSuccessMessage = appState.t(.inviteSentSuccess)
                                                inviteEmail = ""
                                            }
                                            isSendingInvite = false
                                        }
                                    } label: {
                                        Label(
                                            isSendingInvite ? appState.t(.saving) : appState.t(.sendInviteBtn),
                                            systemImage: "envelope.fill"
                                        )
                                        .font(.subheadline.weight(.bold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(MarviColor.rose)
                                    .background(MarviColor.rose.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    .disabled(
                                        isSendingInvite
                                            || inviteEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    )
                                }
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
            .onChange(of: avatarPickerItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        _ = await appState.uploadProfilePhoto(data: data, kind: .avatar)
                    }
                }
            }
            .onChange(of: coverPickerItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        _ = await appState.uploadProfilePhoto(data: data, kind: .cover)
                    }
                }
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
        if !appState.profile.tiktokHandle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { count += 1 }
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
                Group {
                    if let coverURL = URL(string: profile.coverURL), !profile.coverURL.isEmpty {
                        AsyncImage(url: coverURL) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            default:
                                MarviGradient.brandVertical
                            }
                        }
                    } else {
                        MarviGradient.brandVertical
                    }
                }
                .frame(height: 120)
                .clipped()

                profileAvatar
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

    @ViewBuilder
    private var profileAvatar: some View {
        if let avatarURL = URL(string: profile.avatarURL), !profile.avatarURL.isEmpty {
            AsyncImage(url: avatarURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 96, height: 96)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(MarviColor.panel, lineWidth: 3))
                default:
                    SSAvatarRing(initials: initials, size: 96)
                }
            }
        } else {
            SSAvatarRing(initials: initials, size: 96)
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

private struct ProfileInsightPicker: View {
    @Binding var selected: ProfileInsightTab
    let language: AppLanguage

    var body: some View {
        HStack(spacing: 8) {
            ForEach(ProfileInsightTab.allCases, id: \.rawValue) { tab in
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        selected = tab
                    }
                } label: {
                    Text(tab.title(for: language).uppercased())
                        .font(.caption2.weight(.bold))
                        .tracking(0.9)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(selected == tab ? .white : MarviColor.muted)
                        .background(
                            selected == tab
                                ? AnyShapeStyle(MarviGradient.brand)
                                : AnyShapeStyle(MarviColor.panelElevated)
                        )
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct ProfileEngagementPanel: View {
    let profile: CreatorProfile
    let followersLabel: String

    private var cleanAudience: String {
        profile.audienceLabel.replacingOccurrences(of: " audience", with: "")
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                ProfileBigMetric(value: cleanAudience, label: followersLabel, icon: "person.2.fill", tint: MarviColor.rose)
                ProfileBigMetric(value: "\(profile.niches.count)", label: "Niches", icon: "tag.fill", tint: MarviColor.aubergine)
            }

            VStack(spacing: 10) {
                AnalyticsBar(label: "Content fit", value: min(Double(max(profile.niches.count, 1)) / 6.0, 1), tint: MarviColor.rose)
                AnalyticsBar(label: "Languages", value: min(Double(max(profile.languages.count, 1)) / 3.0, 1), tint: MarviColor.blue)
                AnalyticsBar(label: "Delivery", value: proofRateValue, tint: MarviColor.emerald)
            }
        }
    }

    private var proofRateValue: Double {
        let digits = profile.proofRate.filter { $0.isNumber }
        guard let number = Double(digits) else { return 0 }
        return min(number / 100.0, 1)
    }
}

private struct ProfileHealthPanel: View {
    let profile: CreatorProfile
    let healthLabel: String

    var body: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                ProfileBigMetric(value: "\(profile.score)", label: "Score", icon: "star.fill", tint: MarviColor.gold)
                ProfileBigMetric(value: profile.proofRate, label: "Delivery", icon: "checkmark.seal.fill", tint: MarviColor.emerald)
            }

            Spacer()

            ProfileHealthRing(score: profile.score, label: healthLabel)
        }
    }
}

private struct ProfileBigMetric: View {
    let value: String
    let label: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.headline.weight(.semibold))
                .foregroundStyle(tint)

            Text(value)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(MarviColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(MarviColor.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(MarviColor.panelElevated)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct AnalyticsBar: View {
    let label: String
    let value: Double
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MarviColor.graphite)
                Spacer()
                Text("\(Int(value * 100))%")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(tint)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(MarviColor.panelElevated)
                    Capsule()
                        .fill(tint)
                        .frame(width: geo.size.width * value)
                }
            }
            .frame(height: 7)
        }
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
