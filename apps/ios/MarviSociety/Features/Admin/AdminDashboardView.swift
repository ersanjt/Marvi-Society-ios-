import SwiftUI

struct AdminDashboardView: View {
    @EnvironmentObject private var appState: AppState

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
                        }

                        SectionTitle(title: "Review queue", subtitle: "Approve or reject items before they go live.")

                        ForEach(appState.adminTasks) { task in
                            AdminTaskCard(task: task) {
                                appState.approveTask(task)
                            } reject: {
                                appState.rejectTask(task)
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Admin")
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
    let approve: () -> Void
    let reject: () -> Void

    var body: some View {
        MarviCard {
            VStack(alignment: .leading, spacing: 12) {
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
                    }

                    Spacer()
                }

                HStack(spacing: 10) {
                    InfoBadge(icon: "calendar", text: task.dateLabel)
                    InfoBadge(icon: "flag", text: task.priority)
                }

                if task.status == .open {
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
}
