import MapKit
import PhotosUI
import SwiftUI

enum AdminConsoleTab: String, CaseIterable, Identifiable {
    case queue
    case campaigns
    case users
    case map
    case broadcast
    case activity

    var id: String { rawValue }

    func title(for language: AppLanguage) -> String {
        switch self {
        case .queue: MarviL10n.t(.adminTabQueue, language: language)
        case .campaigns: language == .turkish ? "Kampanya" : "Campaigns"
        case .users: MarviL10n.t(.adminTabUsers, language: language)
        case .map: MarviL10n.t(.adminTabMap, language: language)
        case .broadcast: MarviL10n.t(.adminTabBroadcast, language: language)
        case .activity: MarviL10n.t(.adminTabActivity, language: language)
        }
    }

    var icon: String {
        switch self {
        case .queue: "tray.full"
        case .campaigns: "megaphone.fill"
        case .users: "person.3"
        case .map: "map"
        case .broadcast: "megaphone"
        case .activity: "waveform.path.ecg"
        }
    }
}

struct AdminUsersTab: View {
    @EnvironmentObject private var appState: AppState
    @State private var searchText = ""
    @State private var selectedUser: AdminUserSummary?
    @State private var statusFilter: String? = nil
    @State private var inviteEmail = ""
    @State private var inviteCode = ""
    @State private var inviteMaxUses = "1"
    @State private var newInviteCode = ""
    @State private var newInviteEmail = ""
    @State private var newInviteOwnerType = "creator"
    @State private var newInviteMaxUses = "1"
    @State private var quotaDrafts: [String: String] = [:]
    @State private var createEmail = ""
    @State private var createName = ""
    @State private var createCity = "istanbul"
    @State private var createPassword = ""
    @State private var actionMessage = ""
    @State private var showTools = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionTitle(
                    title: appState.t(.adminUsersDirectoryTitle),
                    subtitle: appState.t(.adminUsersDirectorySub)
                )

                statusFilterBar

                HStack {
                    Text("\(filteredUsers.count) \(appState.t(.adminUsersCountLabel))")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(MarviColor.muted)
                    Spacer()
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { showTools.toggle() }
                    } label: {
                        Label(
                            showTools ? appState.t(.adminHideTools) : appState.t(.adminShowTools),
                            systemImage: showTools ? "chevron.up" : "slider.horizontal.3"
                        )
                        .font(.caption.weight(.bold))
                        .foregroundStyle(MarviColor.rose)
                    }
                    .buttonStyle(.plain)
                }

                if showTools {
                    inviteCodesSection

                    MarviCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(appState.t(.createAccountDirect))
                                .font(.caption.weight(.bold))
                                .textCase(.uppercase)
                                .foregroundStyle(MarviColor.muted)

                            MarviTextField(placeholder: "Email", text: $createEmail, autocapitalization: .never)
                            MarviTextField(placeholder: "Full name", text: $createName)
                            MarviTextField(placeholder: "City", text: $createCity)
                            MarviTextField(placeholder: "Password (optional)", text: $createPassword, autocapitalization: .never)

                            Button {
                                Task {
                                    actionMessage = ""
                                    let outcome = await appState.adminCreateUserAccount(
                                        email: createEmail,
                                        password: createPassword.isEmpty ? nil : createPassword,
                                        fullName: createName,
                                        city: createCity
                                    )
                                    if let error = outcome.error {
                                        actionMessage = error
                                    } else if let result = outcome.result {
                                        if let temp = result.temporaryPassword, !temp.isEmpty {
                                            actionMessage = "Created \(result.email). Temp password: \(temp)"
                                        } else {
                                            actionMessage = "Created \(result.email)."
                                        }
                                        createEmail = ""
                                        createPassword = ""
                                    }
                                }
                            } label: {
                                Label("Create & approve", systemImage: "person.badge.plus")
                                    .font(.subheadline.weight(.bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.white)
                            .background(MarviColor.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .disabled(createEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }

                    MarviCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(appState.t(.sendInviteEmail))
                                .font(.caption.weight(.bold))
                                .textCase(.uppercase)
                                .foregroundStyle(MarviColor.muted)

                            MarviTextField(placeholder: "Email", text: $inviteEmail, autocapitalization: .never)
                            MarviTextField(
                                placeholder: appState.t(.adminInviteCodeLabel) + " (optional)",
                                text: $inviteCode,
                                autocapitalization: .never
                            )
                            MarviTextField(
                                placeholder: appState.t(.adminInviteQuotaPh),
                                text: $inviteMaxUses,
                                autocapitalization: .never
                            )

                            Button {
                                Task {
                                    actionMessage = ""
                                    let maxUses = Int(inviteMaxUses.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 1
                                    if let error = await appState.adminSendInviteEmail(
                                        email: inviteEmail,
                                        inviteCode: inviteCode.isEmpty ? nil : inviteCode,
                                        maxUses: maxUses
                                    ) {
                                        actionMessage = error
                                    } else {
                                        if let summary = appState.lastInviteActionSummary {
                                            actionMessage = "\(appState.t(.inviteEmailQueued)): \(summary)"
                                        } else {
                                            actionMessage = appState.t(.inviteEmailQueued)
                                        }
                                        inviteEmail = ""
                                        inviteCode = ""
                                    }
                                }
                            } label: {
                                Label(appState.t(.sendInviteEmail), systemImage: "envelope.badge")
                                    .font(.subheadline.weight(.bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.white)
                            .background(MarviGradient.brand)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .disabled(inviteEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }

                if !actionMessage.isEmpty {
                    Text(actionMessage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MarviColor.emerald)
                }

                if appState.adminUsers.isEmpty {
                    MarviCard {
                        EmptyStateView(
                            title: appState.t(.noUsersLoaded),
                            subtitle: appState.t(.noUsersLoadedSub),
                            icon: "person.3",
                            actionTitle: appState.t(.refresh),
                            action: { Task { await appState.loadAdminUsers(search: searchText, status: statusFilter) } }
                        )
                    }
                } else if filteredUsers.isEmpty {
                    MarviCard {
                        EmptyStateView(
                            title: appState.t(.adminUsersFilterEmpty),
                            subtitle: appState.t(.adminUsersFilterEmptySub),
                            icon: "line.3.horizontal.decrease.circle",
                            actionTitle: appState.t(.adminClearFilters),
                            action: {
                                searchText = ""
                                statusFilter = nil
                                Task { await appState.loadAdminUsers() }
                            }
                        )
                    }
                } else {
                    ForEach(filteredUsers) { user in
                        Button {
                            selectedUser = user
                        } label: {
                            AdminUserRow(user: user)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
        }
        .searchable(text: $searchText, prompt: appState.t(.searchUsersPrompt))
        .onSubmit(of: .search) {
            Task { await appState.loadAdminUsers(search: searchText, status: statusFilter) }
        }
        .refreshable {
            await appState.loadAdminUsers(search: searchText, status: statusFilter)
            await appState.loadAdminInviteCodes()
        }
        .task {
            if appState.adminUsers.isEmpty {
                await appState.loadAdminUsers()
            }
            if appState.adminInviteCodes.isEmpty {
                await appState.loadAdminInviteCodes()
            }
        }
        .sheet(item: $selectedUser) { user in
            AdminUserDetailSheet(user: user)
                .environmentObject(appState)
        }
    }

    private var statusFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(title: appState.t(.adminFilterAll), value: nil)
                filterChip(title: "approved", value: "approved")
                filterChip(title: "under_review", value: "under_review")
                filterChip(title: "paused", value: "paused")
            }
        }
    }

    private func filterChip(title: String, value: String?) -> some View {
        let selected = statusFilter == value
        return Button {
            statusFilter = value
            Task { await appState.loadAdminUsers(search: searchText, status: statusFilter) }
        } label: {
            Text(title)
                .font(.caption.weight(.bold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .foregroundStyle(selected ? Color.white : MarviColor.ink)
                .background(selected ? MarviColor.rose : MarviColor.panelElevated)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var inviteCodesSection: some View {
        MarviCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(
                    title: appState.t(.adminCreateInviteCode),
                    subtitle: appState.t(.adminInvitesSub)
                )

                if appState.adminInviteCodes.isEmpty {
                    EmptyStateView(
                        title: appState.t(.adminInvitesEmpty),
                        subtitle: appState.t(.adminInvitesEmptySub),
                        icon: "ticket",
                        actionTitle: appState.t(.refresh),
                        action: { Task { await appState.loadAdminInviteCodes() } }
                    )
                } else {
                    ForEach(appState.adminInviteCodes) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(item.code)
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(MarviColor.ink)
                                Spacer()
                                InfoBadge(icon: "person.2", text: item.quotaLabel)
                            }
                            HStack(spacing: 8) {
                                InfoBadge(icon: "tag", text: item.ownerType)
                                if let email = item.inviteEmail, !email.isEmpty {
                                    InfoBadge(icon: "envelope", text: email)
                                }
                            }
                            HStack(spacing: 8) {
                                MarviTextField(
                                    placeholder: appState.t(.adminInviteQuotaPh),
                                    text: quotaBinding(for: item),
                                    autocapitalization: .never
                                )
                                Button {
                                    Task {
                                        let draft = quotaDrafts[item.code] ?? String(item.maxUses ?? 1)
                                        let maxUses = Int(draft.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 1
                                        if let error = await appState.adminUpdateInviteCodeQuota(
                                            code: item.code,
                                            maxUses: maxUses
                                        ) {
                                            actionMessage = error
                                        } else {
                                            actionMessage = appState.t(.adminUpdateInviteQuota)
                                        }
                                    }
                                } label: {
                                    Text(appState.t(.adminUpdateInviteQuota))
                                        .font(.caption.weight(.bold))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.white)
                                .background(MarviColor.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                        }
                        .padding(.vertical, 4)
                        if item.id != appState.adminInviteCodes.last?.id {
                            Divider()
                        }
                    }
                }

                Divider()

                Text(appState.t(.adminCreateInviteCode))
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(MarviColor.muted)

                MarviTextField(
                    placeholder: appState.t(.adminInviteCodeLabel) + " (optional)",
                    text: $newInviteCode,
                    autocapitalization: .never
                )
                MarviTextField(
                    placeholder: appState.t(.inviteEmailPlaceholder),
                    text: $newInviteEmail,
                    autocapitalization: .never
                )
                Picker(appState.t(.roleLabel), selection: $newInviteOwnerType) {
                    Text("Creator").tag("creator")
                    Text("Venue").tag("venue")
                }
                .pickerStyle(.segmented)
                MarviTextField(
                    placeholder: appState.t(.adminInviteQuotaPh),
                    text: $newInviteMaxUses,
                    autocapitalization: .never
                )

                Button {
                    Task {
                        let maxUses = Int(newInviteMaxUses.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 1
                        let email = newInviteEmail.trimmingCharacters(in: .whitespacesAndNewlines)
                        if let error = await appState.adminCreateInviteCode(
                            code: newInviteCode.isEmpty ? nil : newInviteCode,
                            ownerType: newInviteOwnerType,
                            maxUses: maxUses,
                            inviteEmail: email.isEmpty ? nil : email
                        ) {
                            actionMessage = error
                        } else {
                            if let summary = appState.lastInviteActionSummary {
                                actionMessage = email.isEmpty
                                    ? "\(appState.t(.adminCreateInviteCode)): \(summary)"
                                    : "\(appState.t(.inviteEmailQueued)): \(summary)"
                            } else {
                                actionMessage = appState.t(.adminCreateInviteCode)
                            }
                            newInviteCode = ""
                            newInviteEmail = ""
                        }
                    }
                } label: {
                    Label(appState.t(.adminCreateInviteCode), systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(MarviGradient.brand)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }

    private func quotaBinding(for item: AdminInviteCodeItem) -> Binding<String> {
        Binding(
            get: {
                quotaDrafts[item.code] ?? String(item.maxUses ?? 1)
            },
            set: { quotaDrafts[item.code] = $0 }
        )
    }


    private var filteredUsers: [AdminUserSummary] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return appState.adminUsers }
        return appState.adminUsers.filter {
            $0.displayName.lowercased().contains(query)
                || ($0.email?.lowercased().contains(query) ?? false)
                || ($0.city?.lowercased().contains(query) ?? false)
                || ($0.instagramHandle?.lowercased().contains(query) ?? false)
        }
    }
}

private struct AdminUserRow: View {
    @EnvironmentObject private var appState: AppState
    let user: AdminUserSummary

    var body: some View {
        MarviCard {
            HStack(spacing: 12) {
                AdminAvatarView(urlString: user.avatarURL, initials: user.initials, size: 52)

                VStack(alignment: .leading, spacing: 4) {
                    Text(user.displayName)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(MarviColor.ink)
                        .lineLimit(1)
                    Text(user.email ?? appState.t(.noEmail))
                        .font(.caption)
                        .foregroundStyle(MarviColor.muted)
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        StatusPill(text: user.status ?? "unknown", tint: statusTint, systemImage: "circle.fill")
                        if let city = user.city, !city.isEmpty {
                            InfoBadge(icon: "mappin", text: city)
                        }
                        if user.hasLiveLocation {
                            InfoBadge(icon: "location.fill", text: appState.t(.liveStatusLabel))
                        }
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .foregroundStyle(MarviColor.muted)
            }
        }
    }

    private var statusTint: Color {
        switch user.status?.lowercased() {
        case "approved": MarviColor.emerald
        case "paused": MarviColor.tomato
        default: MarviColor.gold
        }
    }
}

private struct AdminAvatarView: View {
    let urlString: String?
    let initials: String
    var size: CGFloat = 48

    var body: some View {
        ZStack {
            Circle()
                .fill(MarviColor.panelElevated)
            if let urlString, let url = URL(string: urlString), !urlString.isEmpty {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        Text(initials).font(.caption.weight(.bold)).foregroundStyle(MarviColor.muted)
                    default:
                        ProgressView().scaleEffect(0.7)
                    }
                }
            } else {
                Text(initials)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(MarviColor.muted)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(MarviColor.panel, lineWidth: 1))
    }
}

struct AdminUserDetailSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let user: AdminUserSummary

    @State private var detail: AdminUserDetail?
    @State private var notifyTitle = ""
    @State private var notifyBody = ""
    @State private var emailSubject = ""
    @State private var emailBody = ""
    @State private var feedback = ""
    @State private var feedbackIsError = false
    @State private var avatarPickerItem: PhotosPickerItem?
    @State private var coverPickerItem: PhotosPickerItem?
    @State private var isBusy = false
    @State private var openedThread: DirectThread?
    @State private var showPublicProfile = false
    @State private var isOpeningMessage = false

    private var avatarURL: String? { detail?.avatarURL ?? user.avatarURL }
    private var coverURL: String? { detail?.coverURL ?? user.coverURL }
    private var creatorID: UUID? { detail?.creatorID ?? user.creatorID }

    var body: some View {
        NavigationStack {
            MarviScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let detail {
                            mediaHero
                            quickActions
                            photoAdminSection
                            detailSection(detail)
                            actionSection
                            if !detail.bookingSummaries.isEmpty {
                                listSection(title: "Bookings", items: detail.bookingSummaries)
                            }
                            if !detail.strikeSummaries.isEmpty {
                                listSection(title: "Strikes", items: detail.strikeSummaries)
                            }
                        } else {
                            ProgressView(appState.t(.loadingProfile))
                                .frame(maxWidth: .infinity)
                                .padding(.top, 40)
                        }

                        if !feedback.isEmpty {
                            Text(feedback)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(feedbackIsError ? MarviColor.tomato : MarviColor.emerald)
                                .padding(.horizontal, 4)
                        }
                    }
                    .padding(16)
                    .overlay {
                        if isBusy {
                            ZStack {
                                Color.black.opacity(0.25)
                                ProgressView()
                                    .tint(.white)
                                    .padding(20)
                                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                            }
                        }
                    }
                }
            }
            .navigationTitle(user.displayName)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(appState.t(.done)) { dismiss() }
                }
            }
            .task {
                detail = await appState.loadAdminUserDetail(userID: user.userID)
            }
            .onChange(of: avatarPickerItem) { _, item in
                guard let item else { return }
                Task { await handlePhoto(item: item, kind: .avatar) }
            }
            .onChange(of: coverPickerItem) { _, item in
                guard let item else { return }
                Task { await handlePhoto(item: item, kind: .cover) }
            }
            .sheet(item: $openedThread) { thread in
                DirectChatThreadView(thread: thread)
                    .environmentObject(appState)
            }
            .sheet(isPresented: $showPublicProfile) {
                if let creatorID {
                    CreatorPublicProfileView(creatorID: creatorID, fallbackName: user.displayName)
                        .environmentObject(appState)
                }
            }
        }
    }

    private var mediaHero: some View {
        MarviCard {
            VStack(spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    Group {
                        if let coverURL, let url = URL(string: coverURL), !coverURL.isEmpty {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable().scaledToFill()
                                default:
                                    MarviGradient.brand.opacity(0.35)
                                }
                            }
                        } else {
                            MarviGradient.brand.opacity(0.35)
                        }
                    }
                    .frame(height: 140)
                    .frame(maxWidth: .infinity)
                    .clipped()

                    AdminAvatarView(urlString: avatarURL, initials: user.initials, size: 72)
                        .overlay(Circle().stroke(MarviColor.panel, lineWidth: 3))
                        .offset(x: 16, y: 28)
                }
                .padding(.bottom, 36)

                VStack(alignment: .leading, spacing: 4) {
                    Text(user.displayName)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(MarviColor.ink)
                    Text(user.email ?? appState.t(.noEmail))
                        .font(.subheadline)
                        .foregroundStyle(MarviColor.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            .padding(0)
        }
    }

    private var quickActions: some View {
        HStack(spacing: 10) {
            quickButton(appState.t(.sendMessageBtn), icon: "paperplane.fill", tint: MarviColor.rose) {
                isOpeningMessage = true
                openedThread = await appState.openDirectThread(with: user.userID)
                isOpeningMessage = false
                if openedThread == nil {
                    feedbackIsError = true
                    feedback = appState.t(.errSomeDataRefresh)
                }
            }
            .disabled(isOpeningMessage)

            quickButton(appState.t(.adminEmailPhotoHint), icon: "envelope.fill", tint: MarviColor.blue) {
                emailSubject = appState.t(.adminPhotoEmailSubject)
                emailBody = appState.t(.adminPhotoEmailBody)
            }

            quickButton(appState.t(.adminViewPublicProfile), icon: "person.crop.circle", tint: MarviColor.aubergine) {
                if creatorID != nil {
                    showPublicProfile = true
                } else {
                    feedbackIsError = true
                    feedback = appState.t(.adminNoCreatorProfile)
                }
            }
        }
    }

    private func quickButton(_ title: String, icon: String, tint: Color, action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.body.weight(.bold))
                Text(title)
                    .font(.caption2.weight(.bold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(tint)
            .background(tint.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var photoAdminSection: some View {
        MarviCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(appState.t(.adminPhotoToolsTitle))
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(MarviColor.muted)

                HStack(spacing: 10) {
                    PhotosPicker(selection: $avatarPickerItem, matching: .images) {
                        Label(appState.t(.adminChangeAvatar), systemImage: "person.crop.circle.badge.plus")
                            .font(.caption.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(MarviColor.ink)
                    .background(MarviColor.panelElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .disabled(isBusy)

                    Button {
                        Task {
                            isBusy = true
                            if let error = await appState.adminClearUserPhoto(userID: user.userID, kind: .avatar) {
                                feedbackIsError = true
                                feedback = error
                            } else {
                                feedbackIsError = false
                                feedback = appState.t(.adminPhotoCleared)
                                detail = await appState.loadAdminUserDetail(userID: user.userID)
                            }
                            isBusy = false
                        }
                    } label: {
                        Label(appState.t(.adminDeleteAvatar), systemImage: "trash")
                            .font(.caption.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(MarviColor.tomato)
                    .background(MarviColor.tomato.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .disabled(isBusy)
                }

                HStack(spacing: 10) {
                    PhotosPicker(selection: $coverPickerItem, matching: .images) {
                        Label(appState.t(.adminChangeCover), systemImage: "photo.on.rectangle.angled")
                            .font(.caption.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(MarviColor.ink)
                    .background(MarviColor.panelElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .disabled(isBusy)

                    Button {
                        Task {
                            isBusy = true
                            if let error = await appState.adminClearUserPhoto(userID: user.userID, kind: .cover) {
                                feedbackIsError = true
                                feedback = error
                            } else {
                                feedbackIsError = false
                                feedback = appState.t(.adminPhotoCleared)
                                detail = await appState.loadAdminUserDetail(userID: user.userID)
                            }
                            isBusy = false
                        }
                    } label: {
                        Label(appState.t(.adminDeleteCover), systemImage: "trash")
                            .font(.caption.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(MarviColor.tomato)
                    .background(MarviColor.tomato.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .disabled(isBusy)
                }
            }
        }
    }

    @ViewBuilder
    private func detailSection(_ detail: AdminUserDetail) -> some View {
        MarviCard {
            VStack(alignment: .leading, spacing: 8) {
                detailRow(appState.t(.email), detail.email ?? "—")
                detailRow(appState.t(.roleLabel), detail.role ?? "—")
                detailRow(appState.t(.statusField), detail.status ?? "—")
                detailRow(appState.t(.adminInviteCodeLabel), detail.referralCode ?? "—")
                detailRow(appState.t(.cityField), detail.creatorCity ?? user.city ?? "—")
                detailRow(appState.t(.instagramLabel), detail.creatorHandle ?? user.instagramHandle ?? "—")
                if let code = detail.socialVerificationCode {
                    detailRow(appState.t(.socialVerifyCodeLabel), code)
                }
                if let submitted = detail.socialVerificationSubmittedAt {
                    detailRow(appState.t(.socialVerifySubmitted), submitted.formatted(date: .abbreviated, time: .shortened))
                }
                if let verified = detail.socialVerificationVerifiedAt {
                    detailRow(appState.t(.socialVerifyVerified), verified.formatted(date: .abbreviated, time: .shortened))
                }
                if let lat = detail.locationLat, let lng = detail.locationLng {
                    detailRow(appState.t(.lastLocationLabel), String(format: "%.4f, %.4f", lat, lng))
                } else {
                    detailRow(appState.t(.lastLocationLabel), appState.t(.notSharedYet))
                }
            }
        }
    }

    private var actionSection: some View {
        MarviCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(appState.t(.actionsLabel))
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(MarviColor.muted)

                HStack(spacing: 10) {
                    adminActionButton(appState.t(.approve), tint: MarviColor.emerald) {
                        if let error = await appState.adminSetUserStatus(userID: user.userID, status: .approved) {
                            feedbackIsError = true
                            feedback = error
                        } else {
                            feedbackIsError = false
                            feedback = appState.t(.approvedMsg)
                        }
                        detail = await appState.loadAdminUserDetail(userID: user.userID)
                    }
                    adminActionButton(appState.t(.block), tint: MarviColor.tomato) {
                        if let error = await appState.adminSetUserStatus(userID: user.userID, status: .paused) {
                            feedbackIsError = true
                            feedback = error
                        } else {
                            feedbackIsError = false
                            feedback = appState.t(.accountBlocked)
                        }
                        detail = await appState.loadAdminUserDetail(userID: user.userID)
                    }
                }

                Text(appState.t(.adminRoleActions))
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(MarviColor.muted)
                    .padding(.top, 4)

                VStack(spacing: 10) {
                    adminActionButton(appState.t(.adminMakeCreator), tint: MarviColor.rose) {
                        if let error = await appState.adminSetUserRole(userID: user.userID, role: .creator) {
                            feedbackIsError = true
                            feedback = error
                        } else {
                            feedbackIsError = false
                            feedback = appState.t(.adminRoleUpdated)
                        }
                        detail = await appState.loadAdminUserDetail(userID: user.userID)
                    }
                    adminActionButton(appState.t(.adminMakeBusiness), tint: MarviColor.gold) {
                        if let error = await appState.adminSetUserRole(userID: user.userID, role: .venue) {
                            feedbackIsError = true
                            feedback = error
                        } else {
                            feedbackIsError = false
                            feedback = appState.t(.adminRoleUpdated)
                        }
                        detail = await appState.loadAdminUserDetail(userID: user.userID)
                    }
                    adminActionButton(appState.t(.adminMakeAdmin), tint: MarviColor.aubergine) {
                        if let error = await appState.adminSetUserRole(userID: user.userID, role: .admin) {
                            feedbackIsError = true
                            feedback = error
                        } else {
                            feedbackIsError = false
                            feedback = appState.t(.adminRoleUpdated)
                        }
                        detail = await appState.loadAdminUserDetail(userID: user.userID)
                    }
                }

                adminActionButton(appState.t(.socialVerifyConfirmAdmin), tint: MarviColor.emerald) {
                    if let error = await appState.adminVerifySocialDM(userID: user.userID) {
                        feedbackIsError = true
                        feedback = error
                    } else {
                        feedbackIsError = false
                        feedback = appState.t(.socialVerifyVerified)
                    }
                    detail = await appState.loadAdminUserDetail(userID: user.userID)
                }

                MarviTextField(placeholder: appState.t(.notificationTitlePh), text: $notifyTitle)
                MarviTextField(placeholder: appState.t(.notificationBodyPh), text: $notifyBody)
                adminActionButton(appState.t(.sendInAppNotification), tint: MarviColor.rose) {
                    if let error = await appState.adminSendUserNotification(
                        userID: user.userID,
                        title: notifyTitle,
                        body: notifyBody
                    ) {
                        feedbackIsError = true
                        feedback = error
                    } else {
                        feedbackIsError = false
                        feedback = appState.t(.notificationSent)
                    }
                }

                MarviTextField(placeholder: appState.t(.emailSubjectPh), text: $emailSubject)
                MarviTextField(placeholder: appState.t(.emailBodyPh), text: $emailBody)
                adminActionButton(appState.t(.sendEmailBtn), tint: MarviColor.blue) {
                    if let error = await appState.adminSendUserEmail(
                        userID: user.userID,
                        subject: emailSubject,
                        body: emailBody
                    ) {
                        feedbackIsError = true
                        feedback = error
                    } else {
                        feedbackIsError = false
                        feedback = appState.t(.emailQueued)
                    }
                }
            }
        }
    }

    private func listSection(title: String, items: [String]) -> some View {
        MarviCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(MarviColor.muted)
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(.subheadline)
                        .foregroundStyle(MarviColor.ink)
                }
            }
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption.weight(.bold))
                .foregroundStyle(MarviColor.muted)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MarviColor.ink)
                .multilineTextAlignment(.trailing)
        }
    }

    private func adminActionButton(_ title: String, tint: Color, action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            Text(title)
                .font(.caption.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .foregroundStyle(tint == MarviColor.emerald || tint == MarviColor.rose ? .white : MarviColor.ink)
        .background(tint.opacity(tint == MarviColor.emerald || tint == MarviColor.rose ? 1 : 0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func handlePhoto(item: PhotosPickerItem, kind: ProfileImageKind) async {
        isBusy = true
        defer {
            isBusy = false
            if kind == .avatar { avatarPickerItem = nil } else { coverPickerItem = nil }
        }
        do {
            let data = try await PhotosPickerImageLoader.loadData(from: item)
            if let error = await appState.adminUploadUserPhoto(userID: user.userID, data: data, kind: kind) {
                feedbackIsError = true
                feedback = error
            } else {
                feedbackIsError = false
                feedback = appState.t(.adminPhotoUpdated)
                detail = await appState.loadAdminUserDetail(userID: user.userID)
            }
        } catch {
            feedbackIsError = true
            if case let MarviAPIError.server(message) = error {
                feedback = message
            } else {
                feedback = appState.t(.errPhotoTooLarge)
            }
        }
    }
}

struct AdminMapTab: View {
    @EnvironmentObject private var appState: AppState
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 41.015, longitude: 28.979),
            span: MKCoordinateSpan(latitudeDelta: 0.25, longitudeDelta: 0.25)
        )
    )

    var body: some View {
        ZStack(alignment: .top) {
            Map(position: $position) {
                ForEach(mapPins) { pin in
                    Annotation(pin.label, coordinate: pin.coordinate) {
                        VStack(spacing: 2) {
                            Image(systemName: pin.icon)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(6)
                                .background(pin.tint)
                                .clipShape(Circle())
                            Text(pin.label)
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(MarviColor.panel)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .ignoresSafeArea(edges: .bottom)

            MarviCard {
                VStack(alignment: .leading, spacing: 6) {
                    Text(appState.t(.liveMap))
                        .font(.headline.weight(.bold))
                    Text(appState.t(.liveMapLegend))
                        .font(.caption)
                        .foregroundStyle(MarviColor.muted)
                    Text(String(format: appState.t(.liveMapStats), liveUserCount, appState.offers.count))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MarviColor.emerald)
                }
            }
            .padding(16)
        }
        .refreshable {
            await appState.loadAdminUsers()
            await appState.refreshFromServer()
        }
    }

    private var liveUserCount: Int {
        appState.adminUsers.filter(\.hasLiveLocation).count
    }

    private var mapPins: [AdminMapPin] {
        var pins: [AdminMapPin] = []
        for user in appState.adminUsers where user.hasLiveLocation {
            if let lat = user.lastLat, let lng = user.lastLng {
                pins.append(AdminMapPin(
                    id: user.userID.uuidString,
                    coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                    label: user.displayName,
                    icon: "person.fill",
                    tint: MarviColor.rose
                ))
            }
        }
        for offer in appState.offers {
            if let lat = offer.latitude, let lng = offer.longitude {
                pins.append(AdminMapPin(
                    id: offer.id.uuidString,
                    coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                    label: offer.venue,
                    icon: "sparkles",
                    tint: MarviColor.gold
                ))
            }
        }
        return pins
    }
}

private struct AdminMapPin: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let label: String
    let icon: String
    let tint: Color
}

struct AdminBroadcastTab: View {
    @EnvironmentObject private var appState: AppState
    @State private var title = ""
    @State private var bodyText = ""
    @State private var radiusKm = 3.0
    @State private var feedback = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionTitle(
                    title: appState.t(.geoBroadcast),
                    subtitle: appState.t(.geoBroadcastSub)
                )

                MarviCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(appState.t(.radiusLabel))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(MarviColor.muted)
                            Spacer()
                            Text("\(Int(radiusKm)) km")
                                .font(.headline.weight(.bold))
                        }
                        Slider(value: $radiusKm, in: 1...25, step: 1)

                        if let coordinate = appState.userCoordinate {
                            Text(String(format: "Center: %.4f, %.4f (your current location)", coordinate.lat, coordinate.lng))
                                .font(.caption)
                                .foregroundStyle(MarviColor.muted)
                        } else {
                            Text(appState.t(.enableLocationBroadcast))
                                .font(.caption)
                                .foregroundStyle(MarviColor.tomato)
                        }

                        MarviTextField(placeholder: appState.t(.notificationTitlePh), text: $title)
                        MarviTextField(placeholder: appState.t(.notificationBodyPh), text: $bodyText)

                        Button {
                            Task { await sendBroadcast() }
                        } label: {
                            Label(appState.t(.sendToArea), systemImage: "location.circle.fill")
                                .font(.subheadline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.white)
                        .background(MarviGradient.brand)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .disabled(title.isEmpty || bodyText.isEmpty || appState.userCoordinate == nil)

                        if !feedback.isEmpty {
                            Text(feedback)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(MarviColor.emerald)
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    private func sendBroadcast() async {
        feedback = ""
        guard let coordinate = appState.userCoordinate else {
            feedback = appState.t(.locationUnavailable)
            return
        }
        if let message = await appState.adminBroadcastInRadius(
            lat: coordinate.lat,
            lng: coordinate.lng,
            radiusKm: radiusKm,
            title: title,
            body: bodyText
        ) {
            feedback = message
        }
    }
}

struct AdminActivityTab: View {
    private enum ActivityFilter: String, CaseIterable, Identifiable {
        case all, bookings, campaigns, admin, messages, social
        var id: String { rawValue }

        var category: ActivityEventItem.Category {
            switch self {
            case .all: .all
            case .bookings: .bookings
            case .campaigns: .campaigns
            case .admin: .admin
            case .messages: .messages
            case .social: .social
            }
        }

        func title(turkish: Bool) -> String {
            switch self {
            case .all: turkish ? "Tümü" : "All"
            case .bookings: turkish ? "Rezervasyon" : "Bookings"
            case .campaigns: turkish ? "Kampanya" : "Campaigns"
            case .admin: turkish ? "Admin" : "Admin"
            case .messages: turkish ? "Mesaj" : "Messages"
            case .social: turkish ? "Sosyal" : "Social"
            }
        }
    }

    @EnvironmentObject private var appState: AppState
    @State private var filter: ActivityFilter = .all
    @State private var searchText = ""

    private var isTurkish: Bool { appState.preferredLanguage == .turkish }

    private var filteredEvents: [ActivityEventItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return appState.adminActivity.filter { event in
            if filter != .all, event.category != filter.category { return false }
            if query.isEmpty { return true }
            let haystack = [
                event.action,
                event.actorLabel,
                event.subjectType,
                event.meta("title") ?? "",
                event.meta("reason") ?? "",
                event.meta("from") ?? "",
                event.meta("to") ?? ""
            ].joined(separator: " ").lowercased()
            return haystack.contains(query)
        }
    }

    private var counts: [ActivityFilter: Int] {
        let items = appState.adminActivity
        return Dictionary(uniqueKeysWithValues: ActivityFilter.allCases.map { item in
            let count: Int
            if item == .all {
                count = items.count
            } else {
                count = items.filter { $0.category == item.category }.count
            }
            return (item, count)
        })
    }

    private var groupedByDay: [(day: Date, events: [ActivityEventItem])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredEvents) { event in
            calendar.startOfDay(for: event.createdAt)
        }
        return grouped.keys.sorted(by: >).map { day in
            (day, grouped[day]!.sorted { $0.createdAt > $1.createdAt })
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionTitle(
                    title: appState.t(.adminTabActivity),
                    subtitle: isTurkish
                        ? "Canlı operasyon kaydı — rezervasyon, kampanya, admin ve mesajlar."
                        : "Live ops ledger — bookings, campaigns, admin actions, and messages."
                )

                metricsRow

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ActivityFilter.allCases) { item in
                            filterChip(item)
                        }
                    }
                }

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(MarviColor.muted)
                    TextField(
                        isTurkish ? "Ara (üye, aksiyon, sebep)" : "Search member, action, reason",
                        text: $searchText
                    )
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(MarviColor.muted)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(MarviColor.panel)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                if appState.isLoadingAdminActivity && appState.adminActivity.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                } else if let error = appState.adminActivityError, appState.adminActivity.isEmpty {
                    MarviCard {
                        EmptyStateView(
                            title: isTurkish ? "Aktivite yüklenemedi" : "Couldn’t load activity",
                            subtitle: error,
                            icon: "exclamationmark.triangle",
                            actionTitle: appState.t(.retry),
                            action: { Task { await appState.loadAdminActivity() } }
                        )
                    }
                } else if filteredEvents.isEmpty {
                    MarviCard {
                        EmptyStateView(
                            title: appState.t(.adminActivityEmpty),
                            subtitle: searchText.isEmpty
                                ? appState.t(.adminActivityEmptySub)
                                : (isTurkish ? "Bu aramada sonuç yok." : "No results for this search."),
                            icon: "waveform.path.ecg",
                            actionTitle: appState.t(.refresh),
                            action: { Task { await appState.loadAdminActivity() } }
                        )
                    }
                } else {
                    ForEach(groupedByDay, id: \.day) { group in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(dayLabel(for: group.day))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(MarviColor.muted)
                                .textCase(.uppercase)

                            ForEach(group.events) { event in
                                activityRow(event)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .refreshable { await appState.loadAdminActivity() }
        .task { await appState.loadAdminActivity() }
    }

    private var metricsRow: some View {
        HStack(spacing: 8) {
            metricPill(isTurkish ? "Rezervasyon" : "Bookings", counts[.bookings, default: 0], MarviColor.emerald)
            metricPill(isTurkish ? "Kampanya" : "Campaigns", counts[.campaigns, default: 0], MarviColor.aubergine)
            metricPill("Admin", counts[.admin, default: 0], MarviColor.tomato)
        }
    }

    private func metricPill(_ title: String, _ value: Int, _ tint: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.headline.weight(.bold))
                .foregroundStyle(tint)
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(MarviColor.muted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(tint.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func filterChip(_ item: ActivityFilter) -> some View {
        let selected = filter == item
        return Button {
            filter = item
        } label: {
            Text("\(item.title(turkish: isTurkish)) (\(counts[item, default: 0]))")
                .font(.caption.weight(.bold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .foregroundStyle(selected ? Color.white : MarviColor.ink)
                .background(selected ? MarviColor.rose : MarviColor.panel)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func activityRow(_ event: ActivityEventItem) -> some View {
        let style = presentation(for: event)
        return MarviCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: style.icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(style.tint)
                    .frame(width: 36, height: 36)
                    .background(style.tint.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(style.title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(MarviColor.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                        Text(event.createdAt, style: .time)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(MarviColor.graphite)
                    }

                    Text(style.subtitle)
                        .font(.caption)
                        .foregroundStyle(MarviColor.muted)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        Text(style.badge)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(style.tint)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(style.tint.opacity(0.14))
                            .clipShape(Capsule())

                        Text(actorKindLabel(event.actorKind))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(MarviColor.graphite)

                        if let ref = subjectRef(event) {
                            Text(ref)
                                .font(.caption2.monospaced())
                                .foregroundStyle(MarviColor.graphite)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
    }

    private func presentation(for event: ActivityEventItem) -> (title: String, subtitle: String, badge: String, icon: String, tint: Color) {
        let action = event.action.lowercased()
        let title: String
        let icon: String
        let tint: Color
        let badge: String

        switch action {
        case "offer_requested":
            title = isTurkish ? "Teklif talebi" : "Offer requested"
            icon = "hand.raised.fill"
            tint = MarviColor.gold
            badge = isTurkish ? "Rezervasyon" : "Booking"
        case "offer_accepted_pending":
            title = isTurkish ? "Kabul — mekân onayı bekleniyor" : "Accepted — awaiting venue"
            icon = "hourglass"
            tint = MarviColor.gold
            badge = isTurkish ? "Rezervasyon" : "Booking"
        case "venue_confirmed_booking":
            title = isTurkish ? "Mekân rezervasyonu onayladı" : "Venue confirmed booking"
            icon = "checkmark.seal.fill"
            tint = MarviColor.emerald
            badge = isTurkish ? "Rezervasyon" : "Booking"
        case "creator_accepted_collaboration":
            title = isTurkish ? "İşbirliği kabul edildi" : "Collaboration accepted"
            icon = "person.2.fill"
            tint = MarviColor.emerald
            badge = isTurkish ? "Sosyal" : "Social"
        case "creator_shortlisted":
            title = isTurkish ? "Creator shortlist’e alındı" : "Creator shortlisted"
            icon = "star.fill"
            tint = MarviColor.aubergine
            badge = isTurkish ? "Sosyal" : "Social"
        case "message_sent":
            title = isTurkish ? "Mesaj gönderildi" : "Message sent"
            icon = "bubble.left.fill"
            tint = MarviColor.blue
            badge = isTurkish ? "Mesaj" : "Message"
        case "admin_campaign_status":
            let to = event.meta("to") ?? ""
            title = isTurkish ? "Kampanya durumu güncellendi" : "Campaign status updated"
            icon = to == "live" ? "megaphone.fill" : "slider.horizontal.3"
            tint = to == "live" ? MarviColor.emerald : MarviColor.aubergine
            badge = isTurkish ? "Kampanya" : "Campaign"
        case "admin_campaign_deleted":
            title = isTurkish ? "Kampanya silindi" : "Campaign deleted"
            icon = "trash.fill"
            tint = MarviColor.tomato
            badge = isTurkish ? "Kampanya" : "Campaign"
        case "admin_campaign_restored":
            title = isTurkish ? "Kampanya geri alındı" : "Campaign restored"
            icon = "arrow.uturn.backward"
            tint = MarviColor.emerald
            badge = isTurkish ? "Kampanya" : "Campaign"
        case "admin_set_profile_image":
            title = isTurkish ? "Admin profil görseli güncelledi" : "Admin updated profile media"
            icon = "photo.fill"
            tint = MarviColor.rose
            badge = "Admin"
        default:
            title = humanizeAction(event.action)
            icon = iconForCategory(event.category)
            tint = tintForCategory(event.category)
            badge = filterTitle(for: event.category)
        }

        var parts: [String] = []
        parts.append(event.actorLabel)
        if let campaignTitle = event.meta("title") {
            parts.append(campaignTitle)
        }
        if let from = event.meta("from"), let to = event.meta("to") {
            parts.append("\(from) → \(to)")
        } else if let to = event.meta("to") {
            parts.append(to)
        }
        if let reason = event.meta("reason") {
            parts.append(reason)
        }
        if parts.count == 1, !event.subjectType.isEmpty {
            parts.append(event.subjectType)
        }
        let subtitle = parts.joined(separator: " · ")
        return (title, subtitle, badge, icon, tint)
    }

    private func humanizeAction(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    private func filterTitle(for category: ActivityEventItem.Category) -> String {
        switch category {
        case .all: isTurkish ? "Tümü" : "All"
        case .bookings: isTurkish ? "Rezervasyon" : "Booking"
        case .campaigns: isTurkish ? "Kampanya" : "Campaign"
        case .admin: "Admin"
        case .messages: isTurkish ? "Mesaj" : "Message"
        case .social: isTurkish ? "Sosyal" : "Social"
        case .other: isTurkish ? "Diğer" : "Other"
        }
    }

    private func iconForCategory(_ category: ActivityEventItem.Category) -> String {
        switch category {
        case .all, .other: "circle.grid.cross"
        case .bookings: "calendar"
        case .campaigns: "megaphone"
        case .admin: "shield.fill"
        case .messages: "bubble.left"
        case .social: "person.2"
        }
    }

    private func tintForCategory(_ category: ActivityEventItem.Category) -> Color {
        switch category {
        case .all, .other: MarviColor.muted
        case .bookings: MarviColor.emerald
        case .campaigns: MarviColor.aubergine
        case .admin: MarviColor.tomato
        case .messages: MarviColor.blue
        case .social: MarviColor.gold
        }
    }

    private func actorKindLabel(_ kind: String) -> String {
        switch kind.lowercased() {
        case "admin": "Admin"
        case "venue": isTurkish ? "Mekân" : "Venue"
        case "creator": isTurkish ? "Creator" : "Creator"
        case "system": "System"
        default: isTurkish ? "Üye" : "Member"
        }
    }

    private func subjectRef(_ event: ActivityEventItem) -> String? {
        guard let id = event.subjectID else { return nil }
        let type = event.subjectType.isEmpty ? "item" : event.subjectType
        return "\(type) · \(String(id.uuidString.prefix(8)).uppercased())"
    }

    private func dayLabel(for day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) {
            return isTurkish ? "Bugün" : "Today"
        }
        if calendar.isDateInYesterday(day) {
            return isTurkish ? "Dün" : "Yesterday"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: isTurkish ? "tr_TR" : "en_US")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: day)
    }
}

struct AdminCampaignsTab: View {
    private enum CampaignFilter: String, CaseIterable, Identifiable {
        case all, review, live, draft, completed, deleted
        var id: String { rawValue }

        func title(turkish: Bool) -> String {
            switch self {
            case .all: turkish ? "Tümü" : "All"
            case .review: turkish ? "İnceleme" : "Review"
            case .live: turkish ? "Canlı" : "Live"
            case .draft: turkish ? "Taslak / Blok" : "Draft / Blocked"
            case .completed: turkish ? "Tamamlandı" : "Completed"
            case .deleted: turkish ? "Silinen" : "Deleted"
            }
        }
    }

    private enum CampaignAction: Equatable {
        case setStatus(CampaignStatus)
        case softDelete
        case restore
    }

    @EnvironmentObject private var appState: AppState
    @State private var filter: CampaignFilter = .all
    @State private var dialogCampaign: Campaign?
    @State private var dialogAction: CampaignAction?
    @State private var showingStatusConfirm = false
    @State private var actionFeedback = ""

    private var isTurkish: Bool { appState.preferredLanguage == .turkish }

    private var filteredCampaigns: [Campaign] {
        let items = appState.campaigns
        switch filter {
        case .all:
            return items.filter { !$0.isDeleted }
        case .review:
            return items.filter { !$0.isDeleted && $0.status == .review }
        case .live:
            return items.filter { !$0.isDeleted && $0.status == .live }
        case .draft:
            return items.filter { !$0.isDeleted && $0.status == .draft }
        case .completed:
            return items.filter { !$0.isDeleted && $0.status == .completed }
        case .deleted:
            return items.filter(\.isDeleted)
        }
    }

    private var counts: [CampaignFilter: Int] {
        let items = appState.campaigns
        return [
            .all: items.filter { !$0.isDeleted }.count,
            .review: items.filter { !$0.isDeleted && $0.status == .review }.count,
            .live: items.filter { !$0.isDeleted && $0.status == .live }.count,
            .draft: items.filter { !$0.isDeleted && $0.status == .draft }.count,
            .completed: items.filter { !$0.isDeleted && $0.status == .completed }.count,
            .deleted: items.filter(\.isDeleted).count
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionTitle(
                    title: isTurkish ? "Kampanya yönetimi" : "Campaign management",
                    subtitle: isTurkish
                        ? "Onayla ve yayınla, yayından kaldır / engelle, tamamla veya sil. Aktivite sekmesinde izlenir."
                        : "Approve & publish, unpublish/block, complete, or delete. Tracked in Activity."
                )

                metricsRow

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(CampaignFilter.allCases) { item in
                            filterChip(item)
                        }
                    }
                }

                if !actionFeedback.isEmpty {
                    Text(actionFeedback)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MarviColor.emerald)
                }

                if filteredCampaigns.isEmpty {
                    MarviCard {
                        EmptyStateView(
                            title: isTurkish ? "Kampanya yok" : "No campaigns",
                            subtitle: isTurkish
                                ? "Bu filtrede öğe yok. Yenile’ye dokun veya başka bir durum seç."
                                : "Nothing in this filter. Pull to refresh or pick another status.",
                            icon: "megaphone",
                            actionTitle: appState.t(.refresh),
                            action: { Task { await appState.refreshFromServer() } }
                        )
                    }
                } else {
                    ForEach(filteredCampaigns) { campaign in
                        campaignCard(campaign)
                    }
                }
            }
            .padding(16)
        }
        .refreshable { await appState.refreshFromServer() }
        .confirmationDialog(dialogTitle, isPresented: $showingStatusConfirm, titleVisibility: .visible) {
            Button(dialogConfirmLabel, role: dialogIsDestructive ? .destructive : nil) {
                performDialogAction()
            }
            Button(appState.t(.cancel), role: .cancel) {
                clearDialog()
            }
        } message: {
            Text(dialogMessage)
        }
    }

    private var metricsRow: some View {
        HStack(spacing: 8) {
            metricPill(isTurkish ? "İnceleme" : "Review", counts[.review, default: 0], MarviColor.gold)
            metricPill(isTurkish ? "Canlı" : "Live", counts[.live, default: 0], MarviColor.emerald)
            metricPill(isTurkish ? "Blok" : "Blocked", counts[.draft, default: 0], MarviColor.tomato)
        }
    }

    private func metricPill(_ title: String, _ value: Int, _ tint: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.headline.weight(.bold))
                .foregroundStyle(tint)
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(MarviColor.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(tint.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func filterChip(_ item: CampaignFilter) -> some View {
        let selected = filter == item
        return Button {
            filter = item
        } label: {
            Text("\(item.title(turkish: isTurkish)) (\(counts[item, default: 0]))")
                .font(.caption.weight(.bold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .foregroundStyle(selected ? Color.white : MarviColor.ink)
                .background(selected ? MarviColor.rose : MarviColor.panelElevated)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func campaignCard(_ campaign: Campaign) -> some View {
        MarviCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(campaign.title)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(MarviColor.ink)
                        Text("\(campaign.venueName) · \(campaign.area)")
                            .font(.caption)
                            .foregroundStyle(MarviColor.muted)
                        Text("\(campaign.dateLabel) · \(campaign.slots) slot · \(campaign.matchedCreators) matched")
                            .font(.caption2)
                            .foregroundStyle(MarviColor.muted)
                        if let reason = campaign.adminBlockReason, !reason.isEmpty {
                            Text(reason)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(MarviColor.tomato)
                        }
                    }
                    Spacer()
                    statusBadge(for: campaign)
                }

                if appState.processingAdminTaskID == campaign.id {
                    ProgressView()
                        .controlSize(.small)
                }

                FlowActionRow {
                    if campaign.isDeleted {
                        actionButton(isTurkish ? "Geri al" : "Restore", tint: MarviColor.emerald) {
                            queueAction(campaign, .restore)
                        }
                    } else {
                        if campaign.status == .review || campaign.status == .draft {
                            actionButton(isTurkish ? "Onayla / Yayınla" : "Approve / Publish", tint: MarviColor.emerald) {
                                queueAction(campaign, .setStatus(.live))
                            }
                        }
                        if campaign.status == .live {
                            actionButton(isTurkish ? "Yayından kaldır / Engelle" : "Unpublish / Block", tint: MarviColor.tomato) {
                                queueAction(campaign, .setStatus(.draft))
                            }
                        }
                        if campaign.status == .review {
                            actionButton(isTurkish ? "Reddet" : "Reject", tint: MarviColor.tomato) {
                                queueAction(campaign, .setStatus(.draft))
                            }
                        }
                        if campaign.status != .completed {
                            actionButton(isTurkish ? "Tamamla" : "Complete", tint: MarviColor.blue) {
                                queueAction(campaign, .setStatus(.completed))
                            }
                        }
                        if campaign.status == .completed {
                            actionButton(isTurkish ? "Taslağa al" : "To draft", tint: MarviColor.aubergine) {
                                queueAction(campaign, .setStatus(.draft))
                            }
                        }
                        actionButton(isTurkish ? "Sil" : "Delete", tint: MarviColor.tomato) {
                            queueAction(campaign, .softDelete)
                        }
                    }
                }
            }
        }
    }

    private func statusBadge(for campaign: Campaign) -> some View {
        let text: String
        let tint: Color
        if campaign.isDeleted {
            text = isTurkish ? "Silindi" : "Deleted"
            tint = MarviColor.tomato
        } else {
            switch campaign.status {
            case .live:
                text = "Live"
                tint = MarviColor.emerald
            case .review:
                text = isTurkish ? "İnceleme" : "Review"
                tint = MarviColor.gold
            case .draft:
                text = isTurkish ? "Taslak/Blok" : "Draft/Block"
                tint = MarviColor.aubergine
            case .completed:
                text = isTurkish ? "Tamam" : "Done"
                tint = MarviColor.muted
            }
        }
        return Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.15))
            .clipShape(Capsule())
    }

    private func actionButton(_ title: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .foregroundStyle(tint == MarviColor.emerald || tint == MarviColor.rose ? Color.white : MarviColor.ink)
                .background(tint.opacity(tint == MarviColor.emerald || tint == MarviColor.rose ? 1 : 0.14))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(appState.processingAdminTaskID != nil)
    }

    private var dialogTitle: String {
        guard let action = dialogAction else {
            return isTurkish ? "Kampanya güncellensin mi?" : "Update campaign?"
        }
        switch action {
        case .setStatus(.live):
            return isTurkish ? "Yayınlansın mı?" : "Publish campaign?"
        case .setStatus(.draft):
            return isTurkish ? "Yayından kaldırılsın / engellensin mi?" : "Unpublish / block?"
        case .setStatus(.completed):
            return isTurkish ? "Tamamlandı işaretlensin mi?" : "Mark completed?"
        case .setStatus(.review):
            return isTurkish ? "İncelemeye alınsın mı?" : "Send to review?"
        case .softDelete:
            return isTurkish ? "Kampanya silinsin mi?" : "Delete campaign?"
        case .restore:
            return isTurkish ? "Kampanya geri alınsın mı?" : "Restore campaign?"
        }
    }

    private var dialogConfirmLabel: String {
        guard let action = dialogAction else { return appState.t(.confirm) }
        switch action {
        case .softDelete: return isTurkish ? "Sil" : "Delete"
        case .restore: return isTurkish ? "Geri al" : "Restore"
        case .setStatus(.live): return isTurkish ? "Yayınla" : "Publish"
        case .setStatus(.draft): return isTurkish ? "Engelle" : "Block"
        default: return appState.t(.confirm)
        }
    }

    private var dialogIsDestructive: Bool {
        switch dialogAction {
        case .softDelete, .setStatus(.draft): true
        default: false
        }
    }

    private var dialogMessage: String {
        guard let campaign = dialogCampaign, let action = dialogAction else { return "" }
        switch action {
        case .setStatus(.live):
            return isTurkish
                ? "\(campaign.title) Explore’da canlı yayınlanır ve açık inceleme görevi kapanır."
                : "\(campaign.title) goes live on Explore and any open review task is closed."
        case .setStatus(.draft):
            return isTurkish
                ? "\(campaign.title) yayından kalkar / engellenir. Yeni başvurular kabul edilmez."
                : "\(campaign.title) is unpublished/blocked. New accepts stop."
        case .setStatus(.completed):
            return isTurkish
                ? "\(campaign.title) tamamlandı olarak işaretlenir."
                : "\(campaign.title) is marked completed."
        case .softDelete:
            return isTurkish
                ? "\(campaign.title) Explore’dan kaldırılır, açık rezervasyonlar iptal edilir. Kalıcı silme değil."
                : "\(campaign.title) is removed from Explore and open bookings are cancelled. Soft delete."
        case .restore:
            return isTurkish
                ? "\(campaign.title) taslak olarak geri gelir."
                : "\(campaign.title) returns as draft."
        default:
            return campaign.title
        }
    }

    private func queueAction(_ campaign: Campaign, _ action: CampaignAction) {
        dialogCampaign = campaign
        dialogAction = action
        showingStatusConfirm = true
    }

    private func clearDialog() {
        dialogCampaign = nil
        dialogAction = nil
        showingStatusConfirm = false
    }

    private func performDialogAction() {
        guard let campaign = dialogCampaign, let action = dialogAction else {
            clearDialog()
            return
        }
        clearDialog()
        Task {
            switch action {
            case .setStatus(let status):
                let reason: String?
                switch status {
                case .draft:
                    reason = isTurkish ? "Admin tarafından yayından kaldırıldı / engellendi" : "Unpublished / blocked by admin"
                case .live:
                    reason = isTurkish ? "Admin onayladı" : "Approved by admin"
                default:
                    reason = nil
                }
                appState.adminSetCampaignStatus(campaign, status: status, reason: reason)
                actionFeedback = isTurkish ? "Durum güncellendi" : "Status updated"
            case .softDelete:
                let ok = await appState.adminSoftDeleteCampaign(
                    campaign,
                    reason: isTurkish ? "Admin sildi" : "Deleted by admin"
                )
                actionFeedback = ok
                    ? (isTurkish ? "Kampanya silindi" : "Campaign deleted")
                    : (appState.lastSyncError ?? (isTurkish ? "Silinemedi" : "Delete failed"))
            case .restore:
                let ok = await appState.adminRestoreCampaign(campaign)
                actionFeedback = ok
                    ? (isTurkish ? "Kampanya geri alındı" : "Campaign restored")
                    : (appState.lastSyncError ?? (isTurkish ? "Geri alınamadı" : "Restore failed"))
            }
        }
    }
}

/// Simple wrapping row for action chips without introducing a new dependency.
private struct FlowActionRow<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // LazyVGrid keeps buttons usable on narrow widths.
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], alignment: .leading, spacing: 8) {
                content
            }
        }
    }
}
