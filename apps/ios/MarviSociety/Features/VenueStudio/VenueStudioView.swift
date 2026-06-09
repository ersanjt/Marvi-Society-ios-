import SwiftUI

struct VenueStudioView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isShowingBuilder = false

    var body: some View {
        NavigationStack {
            MarviScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        BrandLockup(subtitle: "Venue partner workspace")

                        SectionTitle(
                            title: "Venue studio",
                            subtitle: "Create campaigns, track creator matching, and prepare proof requirements."
                        )

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(SampleData.venueMetrics) { metric in
                                MetricCard(metric: metric)
                            }
                        }

                        PrimaryActionButton(title: "New campaign", systemImage: "plus.circle") {
                            isShowingBuilder = true
                        }

                        SectionTitle(title: "Campaigns", subtitle: "\(appState.campaigns.count) campaigns in this workspace")

                        ForEach(appState.campaigns) { campaign in
                            CampaignCard(campaign: campaign)
                        }

                        MarviCard {
                            VStack(alignment: .leading, spacing: 12) {
                                SectionTitle(title: "Creator shortlist", subtitle: "Admin can approve, invite, or waitlist members.")

                                ShortlistRow(name: "Aylin Demir", niche: "Food / Beauty", score: "92")
                                ShortlistRow(name: "Mert Kaya", niche: "Nightlife / Fashion", score: "88")
                                ShortlistRow(name: "Selin Aras", niche: "Wellness / Lifestyle", score: "84")
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Studio")
            .sheet(isPresented: $isShowingBuilder) {
                CampaignBuilderSheet()
                    .environmentObject(appState)
            }
        }
    }
}

private struct MetricCard: View {
    let metric: VenueMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: metric.icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(MarviColor.emerald)

            Text(metric.value)
                .font(.title2.weight(.bold))
                .foregroundStyle(MarviColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(metric.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MarviColor.graphite)

            Text(metric.trend)
                .font(.caption)
                .foregroundStyle(MarviColor.muted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(MarviColor.panel)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
    }
}

private struct CampaignCard: View {
    let campaign: Campaign

    var body: some View {
        MarviCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: campaign.category.icon)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(campaign.category.tint)
                        .frame(width: 44, height: 44)
                        .background(campaign.category.tint.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 5) {
                        StatusPill(text: campaign.status.rawValue, tint: statusTint, systemImage: "circle.fill")

                        Text(campaign.title)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(MarviColor.ink)

                        Text("\(campaign.venueName) - \(campaign.area)")
                            .font(.subheadline)
                            .foregroundStyle(MarviColor.muted)
                    }

                    Spacer()
                }

                HStack(spacing: 10) {
                    InfoBadge(icon: "calendar", text: campaign.dateLabel)
                    InfoBadge(icon: "gift", text: campaign.valueLabel)
                    InfoBadge(icon: "person.2", text: "\(campaign.matchedCreators)/\(campaign.slots)")
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Deliverables")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(MarviColor.ink)

                    ForEach(campaign.deliverables, id: \.self) { item in
                        Label(item, systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(MarviColor.graphite)
                    }
                }
            }
        }
    }

    private var statusTint: Color {
        switch campaign.status {
        case .draft: MarviColor.muted
        case .review: MarviColor.gold
        case .live: MarviColor.emerald
        case .completed: MarviColor.blue
        }
    }
}

private struct CampaignBuilderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    @State private var title = "Creator dinner preview"
    @State private var venueName = "Mira Bosphorus"
    @State private var area = "Bebek"
    @State private var category: OfferCategory = .dining
    @State private var dateLabel = "Fri, Jun 26"
    @State private var valueLabel = "Dinner for 2"
    @State private var deliverablesText = "Instagram stories, Short Reel, Review link"
    @State private var slots = 10.0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SectionTitle(title: "Campaign builder", subtitle: "Drafts go to admin review before creators are invited.")

                    MarviCard {
                        VStack(alignment: .leading, spacing: 14) {
                            TextField("Campaign title", text: $title)
                                .textFieldStyle(.roundedBorder)

                            TextField("Venue name", text: $venueName)
                                .textFieldStyle(.roundedBorder)

                            TextField("Area", text: $area)
                                .textFieldStyle(.roundedBorder)

                            Picker("Category", selection: $category) {
                                ForEach(OfferCategory.allCases) { category in
                                    Label(category.rawValue, systemImage: category.icon)
                                        .tag(category)
                                }
                            }
                            .pickerStyle(.menu)

                            TextField("Date", text: $dateLabel)
                                .textFieldStyle(.roundedBorder)

                            TextField("Value", text: $valueLabel)
                                .textFieldStyle(.roundedBorder)

                            TextField("Deliverables, separated by commas", text: $deliverablesText)
                                .textInputAutocapitalization(.sentences)
                                .textFieldStyle(.roundedBorder)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Creator slots: \(Int(slots))")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(MarviColor.ink)

                                Slider(value: $slots, in: 2...30, step: 1)
                            }
                        }
                    }

                    if !canSubmitCampaign {
                        Label("Campaign title, venue, area, value, date, and deliverables are required.", systemImage: "exclamationmark.triangle")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MarviColor.tomato)
                    }

                    PrimaryActionButton(
                        title: "Send to admin review",
                        systemImage: "paperplane.fill",
                        isDisabled: !canSubmitCampaign
                    ) {
                        appState.createCampaign(
                            title: title,
                            venueName: venueName,
                            area: area,
                            category: category,
                            dateLabel: dateLabel,
                            valueLabel: valueLabel,
                            slots: Int(slots),
                            deliverables: campaignDeliverables
                        )
                        dismiss()
                    }
                }
                .padding(16)
            }
            .background(MarviColor.surface.ignoresSafeArea())
            .navigationTitle("New campaign")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var campaignDeliverables: [String] {
        deliverablesText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var canSubmitCampaign: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !venueName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !area.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !dateLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !valueLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !campaignDeliverables.isEmpty
    }
}

private struct ShortlistRow: View {
    let name: String
    let niche: String
    let score: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                MarviColor.aubergine.opacity(0.16)
                Image(systemName: "person.fill")
                    .foregroundStyle(MarviColor.aubergine)
            }
            .frame(width: 42, height: 42)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(MarviColor.ink)

                Text(niche)
                    .font(.caption)
                    .foregroundStyle(MarviColor.muted)
            }

            Spacer()

            StatusPill(text: score, tint: MarviColor.gold, systemImage: "star.fill")
        }
    }
}
