import SwiftUI

struct AdminDashboardView: View {
    @EnvironmentObject private var appState: AppState
    @State private var tab: AdminConsoleTab = .queue
    @State private var selectedTask: AdminTask?
    @State private var pendingAction: AdminTaskAction?
    /// Snapshot used by confirmationDialog so Approve isn't dropped when SwiftUI clears `pendingAction` on dismiss.
    @State private var dialogAction: AdminTaskAction?
    @State private var strikeReason = "Proof not delivered per campaign terms"
    @State private var showingStrikesSheet = false
    @State private var showingTaskConfirm = false
    @State private var showingStrikeAlert = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(AdminConsoleTab.allCases) { section in
                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) { tab = section }
                            } label: {
                                Label(section.title(for: appState.preferredLanguage), systemImage: section.icon)
                                    .font(.caption.weight(.bold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .foregroundStyle(tab == section ? Color.white : MarviColor.muted)
                                    .background(
                                        tab == section
                                            ? AnyShapeStyle(MarviGradient.brand)
                                            : AnyShapeStyle(MarviColor.panel)
                                    )
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .stroke(tab == section ? Color.clear : MarviColor.border, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }

                Group {
                    switch tab {
                    case .queue:
                        adminQueueContent
                    case .bookings:
                        AdminBookingsTab()
                    case .venues:
                        AdminVenuesTab()
                    case .campaigns:
                        AdminCampaignsTab()
                    case .users:
                        AdminUsersTab()
                    case .map:
                        AdminMapTab()
                    case .broadcast:
                        AdminBroadcastTab()
                    case .activity:
                        AdminActivityTab()
                    }
                }
            }
            .navigationTitle(appState.t(.admin))
            .sheet(isPresented: $showingStrikesSheet) {
                AdminStrikesSheet()
                    .environmentObject(appState)
            }
            .sheet(item: $selectedTask) { task in
                AdminTaskDetailSheet(task: task) { action in
                    selectedTask = nil
                    queueAction(AdminTaskAction(task: task, kind: action))
                }
                .environmentObject(appState)
            }
            .confirmationDialog(
                dialogAction?.dialogTitle(for: appState.preferredLanguage) ?? appState.t(.confirm),
                isPresented: $showingTaskConfirm,
                titleVisibility: .visible
            ) {
                if let action = dialogAction {
                    Button(action.confirmLabel(for: appState.preferredLanguage), role: action.kind == .reject ? .destructive : nil) {
                        perform(action)
                    }
                    Button(appState.t(.cancel), role: .cancel) {
                        clearPendingActions()
                    }
                }
            } message: {
                if let action = dialogAction {
                    Text(action.message(for: appState.preferredLanguage))
                }
            }
            .alert(appState.t(.issueStrikeTitle), isPresented: $showingStrikeAlert) {
                TextField(appState.t(.reasonLabel), text: $strikeReason)
                Button(appState.t(.issueStrike), role: .destructive) {
                    if let action = dialogAction {
                        appState.issueStrikeForProofTask(
                            action.task,
                            reason: strikeReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? appState.t(.strikeDefaultReason)
                                : strikeReason
                        )
                    }
                    clearPendingActions()
                }
                Button(appState.t(.cancel), role: .cancel) {
                    clearPendingActions()
                }
            } message: {
                Text(appState.t(.strikePolicyMessage))
            }
        }
    }

    private func queueAction(_ action: AdminTaskAction) {
        pendingAction = action
        dialogAction = action
        if action.kind == .strike {
            showingStrikeAlert = true
        } else {
            showingTaskConfirm = true
        }
    }

    private func clearPendingActions() {
        pendingAction = nil
        dialogAction = nil
        showingTaskConfirm = false
        showingStrikeAlert = false
    }

    private func perform(_ action: AdminTaskAction) {
        switch action.kind {
        case .approve:
            appState.approveTask(action.task)
        case .reject:
            appState.rejectTask(action.task)
        case .strike:
            break
        }
        clearPendingActions()
    }

    private var adminQueueContent: some View {
        MarviScreen {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        BrandLockup(subtitle: appState.t(.operationsCommand))

                        SectionTitle(
                            title: appState.t(.adminControl),
                            subtitle: appState.t(.adminControlSub)
                        )

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            AdminMetric(
                                value: "\(appState.openAdminTasks.count)",
                                label: appState.t(.openTasks),
                                icon: "tray",
                                tint: MarviColor.tomato
                            ) {
                                withAnimation {
                                    tab = .queue
                                    proxy.scrollTo("review-queue", anchor: .top)
                                }
                            }
                            AdminMetric(
                                value: "\(appState.adminUsers.count)",
                                label: appState.t(.usersLabel),
                                icon: "person.3",
                                tint: MarviColor.blue
                            ) {
                                tab = .users
                                Task { await appState.loadAdminUsers() }
                            }
                            AdminMetric(
                                value: "\(appState.adminVenues.count)",
                                label: appState.t(.venuesLabel),
                                icon: "building.2",
                                tint: MarviColor.aubergine
                            ) {
                                tab = .venues
                                Task { await appState.loadAdminVenues() }
                            }
                            AdminMetric(
                                value: "\(appState.adminBookings.count)",
                                label: appState.t(.bookingsLabel),
                                icon: "calendar",
                                tint: MarviColor.emerald
                            ) {
                                tab = .bookings
                                Task { await appState.loadAdminBookings() }
                            }
                            AdminMetric(
                                value: "\(appState.strikes.count)",
                                label: appState.t(.strikesLabel),
                                icon: "exclamationmark.triangle",
                                tint: MarviColor.tomato
                            ) {
                                showingStrikesSheet = true
                            }
                        }

                        SectionTitle(title: appState.t(.reviewQueue), subtitle: appState.t(.reviewQueueSub))
                            .id("review-queue")

                    if appState.openAdminTasks.isEmpty {
                        MarviCard {
                            EmptyStateView(
                                title: appState.isSyncing ? appState.t(.queueLoading) : appState.t(.queueEmpty),
                                subtitle: appState.isSyncing
                                    ? appState.t(.queueLoadingSub)
                                    : appState.t(.queueEmptySub),
                                icon: "tray",
                                actionTitle: appState.t(.refresh),
                                action: { Task { await appState.refreshFromServer() } }
                            )
                        }
                    } else {
                        ForEach(appState.openAdminTasks) { task in
                            AdminTaskCard(
                                task: task,
                                isProcessing: appState.processingAdminTaskID == task.id
                            ) {
                                queueAction(AdminTaskAction(task: task, kind: .approve))
                            } reject: {
                                queueAction(AdminTaskAction(task: task, kind: .reject))
                            } strike: {
                                queueAction(AdminTaskAction(task: task, kind: .strike))
                            } openDetail: {
                                selectedTask = task
                            }
                        }
                    }
                }
                .padding(16)
            }
            .refreshable { await appState.refreshFromServer() }
            }
        }
    }
}

private struct AdminTaskAction {
    enum Kind {
        case approve
        case reject
        case strike
    }

    let task: AdminTask
    let kind: Kind

    var dialogTitle: String { dialogTitle(for: .english) }

    func dialogTitle(for language: AppLanguage) -> String {
        switch kind {
        case .approve: language == .turkish ? "Görev onaylansın mı?" : "Approve task?"
        case .reject: language == .turkish ? "Görev reddedilsin mi?" : "Reject task?"
        case .strike: language == .turkish ? "Uyarı verilsin mi?" : "Issue strike?"
        }
    }

    var confirmLabel: String { confirmLabel(for: .english) }

    func confirmLabel(for language: AppLanguage) -> String {
        switch kind {
        case .approve: MarviL10n.t(.approve, language: language)
        case .reject: MarviL10n.t(.decline, language: language)
        case .strike: MarviL10n.t(.issueStrike, language: language)
        }
    }

    var message: String { message(for: .english) }

    func message(for language: AppLanguage) -> String {
        switch kind {
        case .approve:
            switch task.type {
            case .creatorApplication:
                language == .turkish ? "Creator üyeliği ve Keşfet erişimi aktif olur." : "This activates creator membership and Explore access."
            case .venueApplication:
                language == .turkish ? "Mekân Stüdyo çalışma alanı açılır." : "This enables the venue Studio workspace."
            case .campaignReview:
                language == .turkish ? "Kampanya Keşfet'te canlı yayınlanır." : "This publishes the campaign live on Explore."
            case .proofReview:
                language == .turkish ? "Kanıt teslim edildi olarak işaretlenir." : "This marks proof as delivered."
            case .socialVerification:
                language == .turkish ? "Instagram DM kodu doğrulanır ve sosyal hesaplar onaylanır." : "This confirms the Instagram DM verification code and social ownership."
            }
        case .reject:
            language == .turkish ? "Başvuran yeniden gönderene kadar duraklatılmış kalır." : "The applicant or submitter will remain paused until they resubmit."
        case .strike:
            MarviL10n.t(.strikePolicyMessage, language: language)
        }
    }
}

private struct AdminMetric: View {
    let value: String
    let label: String
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.headline)
                        .foregroundStyle(tint)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(MarviColor.muted)
                }

                Text(value)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(MarviColor.ink)

                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MarviColor.muted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(MarviColor.panel)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(MarviColor.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct AdminStrikesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            MarviScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if appState.strikes.isEmpty {
                            EmptyStateView(
                                title: appState.t(.strikesLabel),
                                subtitle: appState.t(.noStrikesAdminSub),
                                icon: "exclamationmark.triangle",
                                actionTitle: appState.t(.refresh),
                                action: { Task { await appState.refreshFromServer() } }
                            )
                            .padding(16)
                        } else {
                            ForEach(appState.strikes) { strike in
                                MarviCard {
                                    HStack(alignment: .top, spacing: 10) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundStyle(MarviColor.tomato)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(strike.reason)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(MarviColor.ink)
                                            Text("\(strike.severity.capitalized) · \(strike.createdAtLabel)")
                                                .font(.caption)
                                                .foregroundStyle(MarviColor.muted)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                        }
                    }
                }
            }
            .navigationTitle(appState.t(.strikesLabel))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(appState.t(.close)) { dismiss() }
                }
            }
            .task { await appState.refreshFromServer() }
        }
    }
}

private struct AdminTaskCard: View {
    @EnvironmentObject private var appState: AppState
    let task: AdminTask
    let isProcessing: Bool
    let approve: () -> Void
    let reject: () -> Void
    let strike: () -> Void
    let openDetail: () -> Void

    var body: some View {
        MarviCard {
            VStack(alignment: .leading, spacing: 12) {
                Button(action: openDetail) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: icon)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(tint)
                            .frame(width: 40, height: 40)
                            .background(tint.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                StatusPill(text: task.type.rawValue, tint: tint, systemImage: nil)
                                StatusPill(text: task.status.rawValue, tint: statusTint, systemImage: "circle.fill")
                            }

                            Text(task.title)
                                .font(.headline.weight(.bold))
                                .foregroundStyle(MarviColor.ink)

                            Text(task.subtitle)
                                .font(.subheadline)
                                .foregroundStyle(MarviColor.muted)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(taskActionHint)
                                .font(.caption)
                                .foregroundStyle(MarviColor.graphite)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(MarviColor.muted)
                    }
                }
                .buttonStyle(.plain)

                HStack(spacing: 10) {
                    InfoBadge(icon: "calendar", text: task.dateLabel)
                    InfoBadge(icon: "flag", text: task.priority)
                }

                if task.status == .open {
                    if isProcessing {
                        HStack {
                            ProgressView().tint(MarviColor.rose)
                            Text(appState.t(.updating))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(MarviColor.muted)
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        HStack(spacing: 10) {
                            Button(action: reject) {
                                Label(appState.t(.decline), systemImage: "xmark.circle")
                                    .font(.subheadline.weight(.bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 11)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(MarviColor.tomato)
                            .background(MarviColor.tomato.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                            Button(action: approve) {
                                Label(appState.t(.approve), systemImage: "checkmark.circle")
                                    .font(.subheadline.weight(.bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 11)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.white)
                            .background(MarviColor.emerald)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }

                        if task.type == .proofReview, task.subjectID != nil {
                            Button(action: strike) {
                                Label("Issue strike", systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption.weight(.bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(MarviColor.tomato)
                            .background(MarviColor.tomato.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                }
            }
        }
    }

    private var icon: String {
        switch task.type {
        case .creatorApplication: "person.badge.plus"
        case .venueApplication: "building.2"
        case .campaignReview: "megaphone"
        case .proofReview: "doc.text"
        case .socialVerification: "paperplane.fill"
        }
    }

    private var tint: Color {
        switch task.type {
        case .creatorApplication: MarviColor.blue
        case .venueApplication: MarviColor.aubergine
        case .campaignReview: MarviColor.gold
        case .proofReview: MarviColor.emerald
        case .socialVerification: MarviColor.rose
        }
    }

    private var statusTint: Color {
        switch task.status {
        case .open: MarviColor.tomato
        case .approved: MarviColor.emerald
        case .rejected: MarviColor.muted
        }
    }

    private var taskActionHint: String {
        let tr = appState.preferredLanguage == .turkish
        switch task.type {
        case .creatorApplication:
            return tr
                ? "Onay, içerik üreticisi üyeliğini ve Keşfet erişimini açar."
                : "Approve activates creator membership and Explore access."
        case .venueApplication:
            return tr
                ? "Onay, Mekân Stüdyo çalışma alanını açar."
                : "Approve enables the venue Studio workspace."
        case .campaignReview:
            return tr
                ? "Onay, kampanyayı Keşfet'te canlı yayınlar."
                : "Approve publishes this campaign live on Explore."
        case .proofReview:
            return tr
                ? "Onay kanıtı teslim edilmiş sayar; red takip için işaretler."
                : "Approve marks proof as delivered; reject flags for follow-up."
        case .socialVerification:
            return tr
                ? "Onay, listelenen hesaplar için Instagram DM sahipliğini doğrular."
                : "Approve confirms Instagram DM ownership for the listed handles."
        }
    }
}

private struct AdminTaskDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    let task: AdminTask
    let onAction: (AdminTaskAction.Kind) -> Void

    @State private var subjectDetail: AdminSubjectDetail?
    @State private var isLoadingSubject = false

    var body: some View {
        NavigationStack {
            MarviScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionTitle(title: task.title, subtitle: task.subtitle)

                        MarviCard {
                            VStack(alignment: .leading, spacing: 10) {
                                detailRow("Type", task.type.rawValue)
                                detailRow("Priority", task.priority)
                                detailRow("Status", task.status.rawValue)
                                detailRow("Submitted", task.dateLabel)
                            }
                        }

                        if isLoadingSubject {
                            MarviCard {
                                HStack {
                                    ProgressView().tint(MarviColor.rose)
                                    Text(appState.t(.loadingApplicant))
                                        .font(.subheadline)
                                        .foregroundStyle(MarviColor.muted)
                                }
                            }
                        } else if let subjectDetail {
                            MarviCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(appState.t(.applicantProfile))
                                        .font(.headline.weight(.bold))
                                        .foregroundStyle(MarviColor.ink)

                                    detailRow("Name", subjectDetail.name)
                                    if let handle = subjectDetail.handle {
                                        detailRow("Instagram", handle)
                                    }
                                    if let city = subjectDetail.city {
                                        detailRow("City", city)
                                    }
                                    if let area = subjectDetail.area {
                                        detailRow("Area", area)
                                    }
                                    if let category = subjectDetail.category {
                                        detailRow("Category", category.capitalized)
                                    }
                                    if let score = subjectDetail.score {
                                        detailRow("Score", "\(score)")
                                    }
                                    if let audience = subjectDetail.audienceLabel {
                                        detailRow("Audience", audience)
                                    }
                                    if !subjectDetail.niches.isEmpty {
                                        detailRow("Niches", subjectDetail.niches.joined(separator: ", "))
                                    }
                                    if !subjectDetail.languages.isEmpty {
                                        detailRow(appState.t(.languagesLabel), subjectDetail.languages.joined(separator: ", "))
                                    }
                                    if task.type == .socialVerification {
                                        if let tiktok = subjectDetail.tiktokHandle {
                                            detailRow("TikTok", tiktok)
                                        }
                                        if let code = subjectDetail.socialVerificationCode {
                                            detailRow(appState.t(.socialVerifyCodeLabel), code)
                                        }
                                        if let submitted = subjectDetail.socialVerificationSubmittedAt {
                                            detailRow(
                                                appState.t(.socialVerifySubmitted),
                                                submitted.formatted(date: .abbreviated, time: .shortened)
                                            )
                                        }
                                    }
                                }
                            }
                        }

                        if task.type == .socialVerification, !task.subtitle.isEmpty {
                            MarviCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(appState.t(.reviewContext))
                                        .font(.headline.weight(.bold))
                                        .foregroundStyle(MarviColor.ink)
                                    Text(task.subtitle)
                                        .font(.subheadline)
                                        .foregroundStyle(MarviColor.graphite)
                                        .textSelection(.enabled)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }

                        MarviCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(appState.t(.reviewContext))
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(MarviColor.ink)
                                Text(contextSummary)
                                    .font(.subheadline)
                                    .foregroundStyle(MarviColor.graphite)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        if task.type == .proofReview, let bookingID = task.subjectID,
                           let booking = appState.bookings.first(where: { $0.id == bookingID }) {
                            MarviCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(appState.t(.proofLinks))
                                        .font(.headline.weight(.bold))
                                        .foregroundStyle(MarviColor.ink)
                                    detailRow("Venue", booking.offer.venue)
                                    detailRow("Deadline", booking.proofDeadline)
                                    if booking.proofLinks.isEmpty {
                                        Text(appState.t(.noLinksYet))
                                            .font(.subheadline)
                                            .foregroundStyle(MarviColor.muted)
                                    } else {
                                        ForEach(booking.proofLinks, id: \.self) { link in
                                            if let url = proofURL(from: link) {
                                                Link(destination: url) {
                                                    Label(link, systemImage: "link")
                                                        .font(.caption.weight(.semibold))
                                                        .foregroundStyle(MarviColor.rose)
                                                        .frame(maxWidth: .infinity, alignment: .leading)
                                                }
                                            } else {
                                                Text(link)
                                                    .font(.caption)
                                                    .foregroundStyle(MarviColor.rose)
                                                    .textSelection(.enabled)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        if task.type == .campaignReview, let offerID = task.subjectID,
                           let offer = appState.offers.first(where: { $0.id == offerID })
                            ?? appState.campaigns.first(where: { $0.id == offerID }).map({ campaign in
                                Offer(
                                    id: campaign.id,
                                    title: campaign.title,
                                    venue: campaign.venueName,
                                    area: campaign.area,
                                    category: campaign.category,
                                    dateLabel: campaign.dateLabel,
                                    timeLabel: "",
                                    valueLabel: campaign.valueLabel,
                                    capacity: campaign.slots,
                                    remaining: campaign.slots,
                                    imageName: "venue-placeholder",
                                    description: campaign.title,
                                    deliverables: campaign.deliverables,
                                    requirements: [],
                                    hostNote: "",
                                    collaborationModel: .invitation
                                )
                            }) {
                            MarviCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(appState.t(.campaignDetails))
                                        .font(.headline.weight(.bold))
                                        .foregroundStyle(MarviColor.ink)
                                    detailRow("Venue", offer.venue)
                                    detailRow("Area", offer.area)
                                    detailRow("Value", offer.valueLabel)
                                    detailRow("Slots", "\(offer.capacity)")
                                    if !offer.deliverables.isEmpty {
                                        detailRow("Deliverables", offer.deliverables.joined(separator: ", "))
                                    }
                                }
                            }
                        }

                        if task.status == .open, appState.processingAdminTaskID != task.id {
                            HStack(spacing: 10) {
                                Button {
                                    onAction(.reject)
                                } label: {
                                    Label(appState.t(.decline), systemImage: "xmark.circle")
                                        .font(.subheadline.weight(.bold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(MarviColor.tomato)
                                .background(MarviColor.tomato.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                                Button {
                                    onAction(.approve)
                                } label: {
                                    Label(appState.t(.approve), systemImage: "checkmark.circle")
                                        .font(.subheadline.weight(.bold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.white)
                                .background(MarviColor.emerald)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }

                            if task.type == .proofReview, task.subjectID != nil {
                                Button {
                                    onAction(.strike)
                                } label: {
                                    Label("Issue strike", systemImage: "exclamationmark.triangle.fill")
                                        .font(.caption.weight(.bold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 11)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(MarviColor.tomato)
                                .background(MarviColor.tomato.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Task detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                guard subjectDetail == nil else { return }
                isLoadingSubject = true
                subjectDetail = await appState.loadAdminSubjectDetail(for: task)
                isLoadingSubject = false
            }
        }
    }

    private var contextSummary: String {
        switch task.type {
        case .creatorApplication:
            "Verify Instagram handle, city, and membership fit before approving creator access."
        case .venueApplication:
            "Confirm venue identity, category, and operational readiness."
        case .campaignReview:
            "Check deliverables, slot count, and brand safety before publishing live."
        case .proofReview:
            "Open proof links and confirm deliverables match campaign terms."
        case .socialVerification:
            "Confirm the DM code matches this user and their Instagram/TikTok handles."
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(MarviColor.muted)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MarviColor.ink)
                .multilineTextAlignment(.trailing)
        }
    }

    private func proofURL(from link: String) -> URL? {
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.hasPrefix("http") {
            return URL(string: trimmed)
        }
        return URL(string: "https://\(trimmed)")
    }
}
