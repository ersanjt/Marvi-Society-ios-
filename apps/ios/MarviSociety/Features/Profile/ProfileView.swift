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
    @State private var saveFailed = false
    @State private var nichesText = ""
    @State private var languagesText = ""
    @State private var selectedInsightTab: ProfileInsightTab = .engagement
    @State private var avatarPickerItem: PhotosPickerItem?
    @State private var coverPickerItem: PhotosPickerItem?
    @State private var isUploadingPhoto = false
    @State private var photoUploadMessage: String?
    @State private var photoUploadFailed = false
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
                            avatarPickerItem: $avatarPickerItem,
                            coverPickerItem: $coverPickerItem,
                            isUploadingPhoto: isUploadingPhoto,
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
                                    ProfileEngagementPanel(
                                        profile: appState.profile,
                                        followCounts: appState.followCounts,
                                        followersLabel: appState.t(.followers),
                                        followingLabel: appState.t(.followingLabel)
                                    )
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

                        if appState.selectedRole == .creator {
                            MarviCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    SectionTitle(
                                        title: appState.t(.collaborationHistory),
                                        subtitle: appState.t(.collaborationHistorySub)
                                    )

                                    if appState.collaborationHistory.isEmpty {
                                        EmptyStateView(
                                            title: appState.t(.noCollaborationsYet),
                                            subtitle: appState.t(.noCollaborationsSub),
                                            icon: "building.2",
                                            actionTitle: nil,
                                            action: nil
                                        )
                                    } else {
                                        ForEach(appState.collaborationHistory) { entry in
                                            CollaborationRowView(entry: entry)
                                        }
                                    }
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
                                    .disabled(isUploadingPhoto)

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
                                    .disabled(isUploadingPhoto)
                                }

                                if isUploadingPhoto {
                                    HStack(spacing: 8) {
                                        ProgressView().controlSize(.small)
                                        Text(appState.t(.uploadingPhoto))
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(MarviColor.muted)
                                    }
                                } else if let photoUploadMessage {
                                    Label(
                                        photoUploadMessage,
                                        systemImage: photoUploadFailed ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
                                    )
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(photoUploadFailed ? MarviColor.tomato : MarviColor.emerald)
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
                                    Label(
                                        saveSuccessMessage,
                                        systemImage: saveFailed ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
                                    )
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(saveFailed ? MarviColor.tomato : MarviColor.emerald)
                                }

                                if appState.isAuthenticated {
                                    Button {
                                        Task {
                                            isSavingProfile = true
                                            saveSuccessMessage = nil
                                            saveFailed = false
                                            appState.profile.niches = nichesText
                                                .split(separator: ",")
                                                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                                                .filter { !$0.isEmpty }
                                            appState.profile.languages = languagesText
                                                .split(separator: ",")
                                                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                                                .filter { !$0.isEmpty }
                                            let saved = await appState.saveProfileToServer()
                                            isSavingProfile = false
                                            saveFailed = !saved
                                            saveSuccessMessage = saved
                                                ? appState.t(.profileSavedSuccess)
                                                : (appState.lastSyncError ?? appState.t(.profileSaveFailed))
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

                        if appState.isAuthenticated, appState.selectedRole == .creator {
                            ShowcaseEditorCard()
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
                    .padding(.bottom, 24)
                }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .task {
                await appState.syncAllowedRoles()
                nichesText = appState.profile.niches.joined(separator: ", ")
                languagesText = appState.profile.languages.joined(separator: ", ")
                await appState.loadShowcase()
            }
            .onChange(of: avatarPickerItem) { _, item in
                guard let item else { return }
                Task { await handlePhotoUpload(item: item, kind: .avatar) }
            }
            .onChange(of: coverPickerItem) { _, item in
                guard let item else { return }
                Task { await handlePhotoUpload(item: item, kind: .cover) }
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

    @MainActor
    private func handlePhotoUpload(item: PhotosPickerItem, kind: ProfileImageKind) async {
        isUploadingPhoto = true
        photoUploadMessage = nil
        photoUploadFailed = false
        defer { isUploadingPhoto = false }

        guard let data = try? await item.loadTransferable(type: Data.self), !data.isEmpty else {
            photoUploadFailed = true
            photoUploadMessage = appState.t(.photoUploadFailed)
            return
        }

        let success = await appState.uploadProfilePhoto(data: data, kind: kind)
        photoUploadFailed = !success
        photoUploadMessage = success
            ? appState.t(.photoUploadSuccess)
            : (appState.lastSyncError ?? appState.t(.photoUploadFailed))

        if kind == .avatar { avatarPickerItem = nil } else { coverPickerItem = nil }
    }
}

private struct PremiumProfileHeader: View {
    @EnvironmentObject private var appState: AppState
    let profile: CreatorProfile
    let managementTitle: String
    @Binding var avatarPickerItem: PhotosPickerItem?
    @Binding var coverPickerItem: PhotosPickerItem?
    var isUploadingPhoto: Bool
    let onManagement: () -> Void

    private let avatarSize: CGFloat = 88
    private let coverHeight: CGFloat = 140

    private var initials: String {
        let fromName = profile.name.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined()
        if !fromName.isEmpty { return fromName.uppercased() }
        let fromHandle = profile.handle.replacingOccurrences(of: "@", with: "").prefix(2)
        return fromHandle.isEmpty ? "M" : String(fromHandle).uppercased()
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                coverPicker

                HStack(alignment: .center, spacing: 14) {
                    avatarPicker

                    VStack(alignment: .leading, spacing: 6) {
                        Text(profile.name.isEmpty ? appState.t(.member) : profile.name)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(MarviColor.ink)
                            .lineLimit(2)

                        Text(profile.niches.first ?? appState.t(.creator))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(MarviColor.rose)

                        Text(profile.handle.isEmpty ? appState.t(.handleEmpty) : "@\(profile.handle.replacingOccurrences(of: "@", with: ""))")
                            .font(.caption)
                            .foregroundStyle(profile.handle.isEmpty ? MarviColor.muted.opacity(0.6) : MarviColor.muted)

                        StatusPill(
                            text: profile.status.label(for: appState.preferredLanguage),
                            tint: statusTint(for: profile.status),
                            systemImage: statusIcon(for: profile.status)
                        )
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.top, coverHeight - avatarSize / 2)
            }

            SSManagementButton(title: managementTitle, action: onManagement)
                .padding(.horizontal, 16)
                .padding(.top, avatarSize / 2 + 14)
                .padding(.bottom, 16)
        }
        .background(MarviColor.panel)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(MarviColor.border, lineWidth: 1)
        )
        .overlay {
            if isUploadingPhoto {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.black.opacity(0.35))
                ProgressView()
                    .tint(.white)
            }
        }
    }

    private var coverPicker: some View {
        PhotosPicker(selection: $coverPickerItem, matching: .images) {
            ZStack(alignment: .bottomTrailing) {
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
                .frame(height: coverHeight)
                .frame(maxWidth: .infinity)
                .clipped()

                photoBadge(icon: "camera.fill")
                    .padding(12)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isUploadingPhoto)
        .accessibilityLabel(appState.t(.changeCover))
    }

    private var avatarPicker: some View {
        PhotosPicker(selection: $avatarPickerItem, matching: .images) {
            ZStack(alignment: .bottomTrailing) {
                profileAvatarImage
                photoBadge(icon: "camera.fill", compact: true)
                    .offset(x: 4, y: 4)
            }
        }
        .buttonStyle(.plain)
        .disabled(isUploadingPhoto)
        .accessibilityLabel(appState.t(.changeAvatar))
    }

    @ViewBuilder
    private var profileAvatarImage: some View {
        if let avatarURL = URL(string: profile.avatarURL), !profile.avatarURL.isEmpty {
            AsyncImage(url: avatarURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: avatarSize, height: avatarSize)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(MarviColor.panel, lineWidth: 3))
                default:
                    SSAvatarRing(initials: initials, size: avatarSize)
                }
            }
        } else {
            SSAvatarRing(initials: initials, size: avatarSize)
        }
    }

    private func photoBadge(icon: String, compact: Bool = false) -> some View {
        Image(systemName: icon)
            .font(compact ? .caption2.weight(.bold) : .caption.weight(.bold))
            .foregroundStyle(.white)
            .padding(compact ? 5 : 7)
            .background(.black.opacity(0.45))
            .clipShape(Circle())
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

private struct CollaborationRowView: View {
    @EnvironmentObject private var appState: AppState
    let entry: CollaborationEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.venueName)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(MarviColor.ink)
                    Text([entry.area, entry.dateLabel].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(MarviColor.muted)
                }
                Spacer()
                if let rating = entry.venueRating {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(MarviColor.gold)
                        Text(String(format: "%.1f", rating))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(MarviColor.ink)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(MarviColor.panelElevated)
                    .clipShape(Capsule())
                } else {
                    Text(appState.t(.awaitingVenueRating))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(MarviColor.muted)
                }
            }

            if !entry.venueComment.isEmpty {
                Text("“\(entry.venueComment)”")
                    .font(.caption)
                    .italic()
                    .foregroundStyle(MarviColor.graphite)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if entry.creatorThanked {
                Label(appState.t(.youThanked), systemImage: "checkmark.seal.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(MarviColor.emerald)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(MarviColor.panel)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct ProfileEngagementPanel: View {
    let profile: CreatorProfile
    let followCounts: FollowCounts
    let followersLabel: String
    let followingLabel: String

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                ProfileBigMetric(value: "\(followCounts.followers)", label: followersLabel, icon: "person.2.fill", tint: MarviColor.rose)
                ProfileBigMetric(value: "\(followCounts.following)", label: followingLabel, icon: "person.badge.plus", tint: MarviColor.aubergine)
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

private struct ShowcaseEditorCard: View {
    @EnvironmentObject private var appState: AppState
    @State private var linkText = ""
    @State private var captionText = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var isBusy = false
    @State private var errorMessage: String?

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        MarviCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle(title: appState.t(.showcaseTitle), subtitle: appState.t(.showcaseSubtitle))

                if appState.showcaseItems.isEmpty {
                    Text(appState.t(.showcaseEmpty))
                        .font(.caption)
                        .foregroundStyle(MarviColor.muted)
                } else {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(appState.showcaseItems) { item in
                            ShowcaseTile(item: item) {
                                Task { await appState.deleteShowcaseItem(item) }
                            }
                        }
                    }
                }

                Divider().overlay(MarviColor.border)

                VStack(alignment: .leading, spacing: 10) {
                    MarviTextField(
                        placeholder: appState.t(.showcaseLinkPlaceholder),
                        text: $linkText,
                        autocapitalization: .never
                    )
                    MarviTextField(
                        placeholder: appState.t(.showcaseCaptionPlaceholder),
                        text: $captionText
                    )

                    HStack(spacing: 10) {
                        Button {
                            Task { await addLink() }
                        } label: {
                            Label(appState.t(.showcaseAddLink), systemImage: "link")
                                .font(.caption.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(MarviColor.rose)
                        .background(MarviColor.rose.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .disabled(isBusy || linkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Label(appState.t(.showcaseUploadPhoto), systemImage: "photo.on.rectangle")
                                .font(.caption.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(MarviColor.rose)
                        .background(MarviColor.rose.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .disabled(isBusy)
                    }

                    if isBusy {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text(appState.t(.uploadingPhoto))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(MarviColor.muted)
                        }
                    } else if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MarviColor.tomato)
                    }
                }
            }
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { await addPhoto(item: item) }
        }
    }

    @MainActor
    private func addLink() async {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        let success = await appState.addShowcaseLink(url: linkText, caption: captionText)
        if success {
            linkText = ""
            captionText = ""
        } else {
            errorMessage = appState.lastSyncError ?? appState.t(.photoUploadFailed)
        }
    }

    @MainActor
    private func addPhoto(item: PhotosPickerItem) async {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false; photoItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self), !data.isEmpty else {
            errorMessage = appState.t(.photoUploadFailed)
            return
        }
        let success = await appState.addShowcasePhoto(data: data, caption: captionText)
        if success {
            captionText = ""
        } else {
            errorMessage = appState.lastSyncError ?? appState.t(.photoUploadFailed)
        }
    }
}

private struct ShowcaseTile: View {
    let item: ShowcaseItem
    let onDelete: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let thumb = item.thumbnailURL {
                    AsyncImage(url: thumb) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        case .failure:
                            placeholder(icon: "photo")
                        default:
                            ZStack { MarviColor.aubergine.opacity(0.12); ProgressView().controlSize(.small) }
                        }
                    }
                } else {
                    placeholder(icon: item.mediaType == .video ? "play.rectangle.fill" : "link")
                }
            }
            .frame(height: 110)
            .frame(maxWidth: .infinity)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(alignment: .bottomLeading) {
                if !item.caption.isEmpty {
                    Text(item.caption)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            LinearGradient(
                                colors: [.black.opacity(0.0), .black.opacity(0.65)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if item.externalURL.isEmpty == false {
                    Image(systemName: "arrow.up.right.square.fill")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(8)
                }
            }

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.white, MarviColor.tomato)
                    .padding(6)
            }
            .buttonStyle(.plain)
        }
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture {
            if let url = item.openURL { UIApplication.shared.open(url) }
        }
    }

    private func placeholder(icon: String) -> some View {
        ZStack {
            MarviColor.aubergine.opacity(0.18)
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(MarviColor.rose)
        }
    }
}
