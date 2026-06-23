import MapKit
import SwiftUI

enum AdminConsoleTab: String, CaseIterable, Identifiable {
    case queue
    case users
    case map
    case broadcast

    var id: String { rawValue }

    var title: String {
        switch self {
        case .queue: "Queue"
        case .users: "Users"
        case .map: "Map"
        case .broadcast: "Broadcast"
        }
    }

    var icon: String {
        switch self {
        case .queue: "tray.full"
        case .users: "person.3"
        case .map: "map"
        case .broadcast: "megaphone"
        }
    }
}

struct AdminUsersTab: View {
    @EnvironmentObject private var appState: AppState
    @State private var searchText = ""
    @State private var selectedUser: AdminUserSummary?
    @State private var inviteEmail = ""
    @State private var inviteCode = "TURGUT"
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
                        MarviTextField(placeholder: "Invite code (optional)", text: $inviteCode, autocapitalization: .never)

                        Button {
                            Task {
                                actionMessage = ""
                                if let error = await appState.adminSendInviteEmail(
                                    email: inviteEmail,
                                    inviteCode: inviteCode.isEmpty ? nil : inviteCode
                                ) {
                                    actionMessage = error
                                } else {
                                    actionMessage = appState.t(.inviteEmailQueued)
                                    inviteEmail = ""
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
        }
        .task {
            if appState.adminUsers.isEmpty {
                await appState.loadAdminUsers()
            }
        }
        .sheet(item: $selectedUser) { user in
            AdminUserDetailSheet(user: user)
                .environmentObject(appState)
        }
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
                detailRow(appState.t(.referralLabel), detail.referralCode ?? "—")
                detailRow(appState.t(.cityField), detail.creatorCity ?? user.city ?? "—")
                detailRow(appState.t(.instagramLabel), detail.creatorHandle ?? user.instagramHandle ?? "—")
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
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 41.015, longitude: 28.979),
        span: MKCoordinateSpan(latitudeDelta: 0.25, longitudeDelta: 0.25)
    )

    var body: some View {
        ZStack(alignment: .top) {
            Map(coordinateRegion: $region, annotationItems: mapPins) { pin in
                MapAnnotation(coordinate: pin.coordinate) {
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
