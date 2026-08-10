import MapKit
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionTitle(
                    title: "User directory",
                    subtitle: "Search members, block accounts, send email or in-app notifications."
                )

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
                        Text("Send invite email")
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
                            action: { Task { await appState.loadAdminUsers(search: searchText) } }
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
            Task { await appState.loadAdminUsers(search: searchText) }
        }
        .refreshable {
            await appState.loadAdminUsers(search: searchText)
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
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.displayName)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(MarviColor.ink)
                    Text(user.email ?? appState.t(.noEmail))
                        .font(.caption)
                        .foregroundStyle(MarviColor.muted)
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
                Spacer()
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

    var body: some View {
        NavigationStack {
            MarviScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let detail {
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
                    }
                    .padding(16)
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
                            feedback = error
                        } else {
                            feedback = appState.t(.approvedMsg)
                        }
                        detail = await appState.loadAdminUserDetail(userID: user.userID)
                    }
                    adminActionButton(appState.t(.block), tint: MarviColor.tomato) {
                        if let error = await appState.adminSetUserStatus(userID: user.userID, status: .paused) {
                            feedback = error
                        } else {
                            feedback = appState.t(.accountBlocked)
                        }
                        detail = await appState.loadAdminUserDetail(userID: user.userID)
                    }
                }

                adminActionButton(appState.t(.socialVerifyConfirmAdmin), tint: MarviColor.emerald) {
                    if let error = await appState.adminVerifySocialDM(userID: user.userID) {
                        feedback = error
                    } else {
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
                        feedback = error
                    } else {
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
                        feedback = error
                    } else {
                        feedback = appState.t(.emailQueued)
                    }
                }

                if !feedback.isEmpty {
                    Text(feedback)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MarviColor.emerald)
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
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(
                    title: appState.t(.adminTabActivity),
                    subtitle: appState.t(.adminActivitySub)
                )

                if appState.adminActivity.isEmpty {
                    MarviCard {
                        EmptyStateView(
                            title: appState.t(.adminActivityEmpty),
                            subtitle: appState.t(.adminActivityEmptySub),
                            icon: "waveform.path.ecg",
                            actionTitle: appState.t(.refresh),
                            action: { Task { await appState.loadAdminActivity() } }
                        )
                    }
                } else {
                    ForEach(appState.adminActivity) { event in
                        MarviCard {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(event.action.replacingOccurrences(of: "_", with: " ").capitalized)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(MarviColor.ink)
                                Text("\(event.subjectType) · \(event.actorLabel)")
                                    .font(.caption)
                                    .foregroundStyle(MarviColor.muted)
                                Text(event.createdAt, style: .relative)
                                    .font(.caption2)
                                    .foregroundStyle(MarviColor.graphite)
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
}

struct AdminCampaignsTab: View {
    @EnvironmentObject private var appState: AppState
    @State private var pendingCampaign: Campaign?
    @State private var pendingStatus: CampaignStatus?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionTitle(
                    title: appState.preferredLanguage == .turkish ? "Kampanya yönetimi" : "Campaign management",
                    subtitle: appState.preferredLanguage == .turkish
                        ? "Canlı kampanyaları yayından kaldır, taslağa al veya tamamlandı işaretle."
                        : "Unpublish live campaigns, move to draft, or mark completed."
                )

                if appState.campaigns.isEmpty {
                    MarviCard {
                        EmptyStateView(
                            title: appState.preferredLanguage == .turkish ? "Kampanya yok" : "No campaigns",
                            subtitle: appState.preferredLanguage == .turkish
                                ? "Yenile’ye dokun. Kampanyalar burada listelenir."
                                : "Tap refresh. Campaigns appear here for admin control.",
                            icon: "megaphone",
                            actionTitle: appState.t(.refresh),
                            action: { Task { await appState.refreshFromServer() } }
                        )
                    }
                } else {
                    ForEach(appState.campaigns) { campaign in
                        MarviCard {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(campaign.title)
                                            .font(.headline.weight(.bold))
                                            .foregroundStyle(MarviColor.ink)
                                        Text("\(campaign.venueName) · \(campaign.area)")
                                            .font(.caption)
                                            .foregroundStyle(MarviColor.muted)
                                        Text(campaign.status.rawValue)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(MarviColor.aubergine)
                                    }
                                    Spacer()
                                }

                                HStack(spacing: 8) {
                                    if campaign.status != .live {
                                        Button(appState.preferredLanguage == .turkish ? "Yayınla" : "Publish") {
                                            pendingCampaign = campaign
                                            pendingStatus = .live
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .tint(MarviColor.emerald)
                                    }
                                    if campaign.status == .live {
                                        Button(appState.preferredLanguage == .turkish ? "Yayından kaldır" : "Unpublish") {
                                            pendingCampaign = campaign
                                            pendingStatus = .draft
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                    Button(appState.preferredLanguage == .turkish ? "Tamamla" : "Complete") {
                                        pendingCampaign = campaign
                                        pendingStatus = .completed
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(campaign.status == .completed)
                                }
                                .font(.caption.weight(.semibold))
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .refreshable { await appState.refreshFromServer() }
        .confirmationDialog(
            appState.preferredLanguage == .turkish ? "Kampanya durumu güncellensin mi?" : "Update campaign status?",
            isPresented: Binding(
                get: { pendingCampaign != nil && pendingStatus != nil },
                set: { if !$0 { pendingCampaign = nil; pendingStatus = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(appState.t(.confirm)) {
                if let campaign = pendingCampaign, let status = pendingStatus {
                    appState.adminSetCampaignStatus(campaign, status: status)
                }
                pendingCampaign = nil
                pendingStatus = nil
            }
            Button(appState.t(.cancel), role: .cancel) {
                pendingCampaign = nil
                pendingStatus = nil
            }
        } message: {
            if let campaign = pendingCampaign, let status = pendingStatus {
                Text("\(campaign.title) → \(status.rawValue)")
            }
        }
    }
}
