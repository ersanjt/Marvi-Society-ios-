import SwiftUI

struct AdminDashboardView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedTask: AdminTask?
    @State private var pendingAction: AdminTaskAction?
    @State private var strikeReason = "Proof not delivered per campaign terms"

    var body: some View {
        NavigationStack {
            MarviScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        BrandLockup(subtitle: "Operations command")

                        SectionTitle(
                            title: "Admin control",
                            subtitle: "Review applications, campaigns, proof submissions, and operational risk."
                        )

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            AdminMetric(value: "\(appState.openAdminTasks.count)", label: "Open tasks", icon: "tray", tint: MarviColor.tomato)
                            AdminMetric(value: "\(appState.offers.count)", label: "Live offers", icon: "sparkles", tint: MarviColor.emerald)
                            AdminMetric(value: "\(appState.activeBookings.count)", label: "Bookings", icon: "calendar", tint: MarviColor.blue)
                            AdminMetric(value: "\(appState.campaigns.count)", label: "Campaigns", icon: "megaphone", tint: MarviColor.gold)
                            AdminMetric(value: "\(appState.strikes.count)", label: "Strikes", icon: "exclamationmark.triangle", tint: MarviColor.tomato)
                        }

                        SectionTitle(title: "Review queue", subtitle: "Approve or reject items before they go live.")

                        if appState.openAdminTasks.isEmpty {
                            MarviCard {
                                EmptyStateView(
                                    title: appState.isSyncing ? "Loading queue…" : "Queue is empty",
                                    subtitle: appState.isSyncing
                                        ? "Fetching the latest review tasks from Supabase."
                                        : "No open review tasks. New applications and proof submissions appear here.",
                                    icon: "tray",
                                    actionTitle: "Refresh",
                                    action: { Task { await appState.refreshFromServer() } }
                                )
                            }
                        } else {
                            ForEach(appState.openAdminTasks) { task in
                                AdminTaskCard(
                                    task: task,
                                    isProcessing: appState.processingAdminTaskID == task.id
                                ) {
                                    pendingAction = AdminTaskAction(task: task, kind: .approve)
                                } reject: {
                                    pendingAction = AdminTaskAction(task: task, kind: .reject)
                                } strike: {
                                    pendingAction = AdminTaskAction(task: task, kind: .strike)
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
            .navigationTitle("Admin")
            .sheet(item: $selectedTask) { task in
                AdminTaskDetailSheet(task: task) { action in
                    selectedTask = nil
                    pendingAction = AdminTaskAction(task: task, kind: action)
                }
                .environmentObject(appState)
            }
            .confirmationDialog(
                pendingAction?.dialogTitle ?? "Confirm",
                isPresented: Binding(
                    get: { pendingAction != nil && pendingAction?.kind != .strike },
                    set: { if !$0 { pendingAction = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let pendingAction {
                    Button(pendingAction.confirmLabel, role: pendingAction.kind == .reject ? .destructive : nil) {
                        perform(pendingAction)
                    }
                    Button("Cancel", role: .cancel) {
                        self.pendingAction = nil
                    }
                }
            } message: {
                if let pendingAction {
                    Text(pendingAction.message)
                }
            }
            .alert("Issue strike", isPresented: Binding(
                get: { pendingAction?.kind == .strike },
                set: { if !$0 { pendingAction = nil } }
            )) {
                TextField("Reason", text: $strikeReason)
                Button("Issue strike", role: .destructive) {
                    if let pendingAction {
                        appState.issueStrikeForProofTask(
                            pendingAction.task,
                            reason: strikeReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? "Proof not delivered per campaign terms"
                                : strikeReason
                        )
                    }
                    pendingAction = nil
                }
                Button("Cancel", role: .cancel) {
                    pendingAction = nil
                }
            } message: {
                Text("This records a policy strike against the creator linked to this booking.")
            }
        }
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
        pendingAction = nil
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

    var dialogTitle: String {
        switch kind {
        case .approve: "Approve task?"
        case .reject: "Reject task?"
        case .strike: "Issue strike?"
        }
    }

    var confirmLabel: String {
        switch kind {
        case .approve: "Approve"
        case .reject: "Reject"
        case .strike: "Issue strike"
        }
    }

    var message: String {
        switch kind {
        case .approve:
            switch task.type {
            case .creatorApplication: "This activates creator membership and Explore access."
            case .venueApplication: "This enables the venue Studio workspace."
            case .campaignReview: "This publishes the campaign live on Explore."
            case .proofReview: "This marks proof as delivered."
            }
        case .reject:
            "The applicant or submitter will remain paused until they resubmit."
        case .strike:
            "This records a policy strike against the creator."
        }
    }
}

private struct AdminMetric: View {
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
    }
}

private struct AdminTaskCard: View {
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
                            Text("Updating…")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(MarviColor.muted)
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        HStack(spacing: 10) {
                            Button(action: reject) {
                                Label("Reject", systemImage: "xmark.circle")
                                    .font(.subheadline.weight(.bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 11)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(MarviColor.tomato)
                            .background(MarviColor.tomato.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                            Button(action: approve) {
                                Label("Approve", systemImage: "checkmark.circle")
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
        }
    }

    private var tint: Color {
        switch task.type {
        case .creatorApplication: MarviColor.blue
        case .venueApplication: MarviColor.aubergine
        case .campaignReview: MarviColor.gold
        case .proofReview: MarviColor.emerald
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
        switch task.type {
        case .creatorApplication:
            "Approve activates creator membership and Explore access."
        case .venueApplication:
            "Approve enables venue Studio workspace."
        case .campaignReview:
            "Approve publishes this campaign live on Explore."
        case .proofReview:
            "Approve marks proof as delivered; reject flags for follow-up."
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
                                    Text("Loading applicant details…")
                                        .font(.subheadline)
                                        .foregroundStyle(MarviColor.muted)
                                }
                            }
                        } else if let subjectDetail {
                            MarviCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Applicant profile")
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
                                        detailRow("Languages", subjectDetail.languages.joined(separator: ", "))
                                    }
                                }
                            }
                        }

                        MarviCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Review context")
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
                                    Text("Proof links")
                                        .font(.headline.weight(.bold))
                                        .foregroundStyle(MarviColor.ink)
                                    detailRow("Venue", booking.offer.venue)
                                    detailRow("Deadline", booking.proofDeadline)
                                    if booking.proofLinks.isEmpty {
                                        Text("No links attached yet.")
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
                                    Text("Campaign details")
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
                                    Label("Reject", systemImage: "xmark.circle")
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
                                    Label("Approve", systemImage: "checkmark.circle")
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
