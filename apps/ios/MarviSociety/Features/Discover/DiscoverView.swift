import SwiftUI

private enum OfferFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case saved = "Saved"
    case urgent = "Few slots"

    var id: String { rawValue }
}

struct DiscoverView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedCategory: OfferCategory?
    @State private var selectedModel: CollaborationModel?
    @State private var selectedFilter: OfferFilter = .all
    @State private var searchText = ""
    @State private var selectedOffer: Offer?

    private var filteredOffers: [Offer] {
        appState.offers.filter { offer in
            let matchesCategory = selectedCategory == nil || offer.category == selectedCategory
            let matchesModel = selectedModel == nil || offer.collaborationModel == selectedModel
            let matchesSearch = searchText.isEmpty ||
                offer.title.localizedCaseInsensitiveContains(searchText) ||
                offer.venue.localizedCaseInsensitiveContains(searchText) ||
                offer.area.localizedCaseInsensitiveContains(searchText)
            let matchesFilter: Bool

            switch selectedFilter {
            case .all:
                matchesFilter = true
            case .saved:
                matchesFilter = appState.isSaved(offer)
            case .urgent:
                matchesFilter = offer.remaining <= 4
            }

            return matchesCategory && matchesModel && matchesSearch && matchesFilter
        }
    }

    private var featuredOffer: Offer? {
        filteredOffers.first ?? appState.offers.first
    }

    var body: some View {
        NavigationStack {
            MarviScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        BrandLockup(subtitle: "Istanbul private access")
                            .padding(.top, 8)

                        if let featuredOffer {
                            FeaturedOfferPanel(
                                offer: featuredOffer,
                                isSaved: appState.isSaved(featuredOffer),
                                isAccepted: appState.isAccepted(featuredOffer),
                                open: {
                                selectedOffer = featuredOffer
                                },
                                toggleSaved: {
                                appState.toggleSaved(featuredOffer)
                                }
                            )
                        }

                        QuickMarketBar()

                        FilterStrip(selectedFilter: $selectedFilter)

                        CollaborationModelStrip(selectedModel: $selectedModel)

                        CategorySelector(selectedCategory: $selectedCategory)

                        SectionTitle(
                            title: "Curated invitations",
                            subtitle: "\(filteredOffers.count) matching offers in Istanbul"
                        )

                        LazyVStack(spacing: 14) {
                            ForEach(filteredOffers) { offer in
                                OfferCard(
                                    offer: offer,
                                    isAccepted: appState.isAccepted(offer),
                                    isSaved: appState.isSaved(offer)
                                ) {
                                    selectedOffer = offer
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Venue, area, category")
            .navigationDestination(item: $selectedOffer) { offer in
                OfferDetailView(offer: offer)
            }
        }
    }
}

private struct FeaturedOfferPanel: View {
    let offer: Offer
    let isSaved: Bool
    let isAccepted: Bool
    let open: () -> Void
    let toggleSaved: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tonight's priority match")
                        .font(.caption.weight(.bold))
                        .textCase(.uppercase)
                        .foregroundStyle(MarviColor.gold)

                    Text(offer.title)
                        .font(.system(size: 34, weight: .bold, design: .serif))
                        .foregroundStyle(.white)
                        .lineLimit(3)
                        .minimumScaleFactor(0.82)

                    Label("\(offer.venue) - \(offer.area)", systemImage: "mappin.and.ellipse")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(1)
                }

                Spacer()

                Button(action: toggleSaved) {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(isSaved ? MarviColor.gold : .white)
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                StatusPill(text: offer.category.rawValue, tint: .white, systemImage: offer.category.icon)
                StatusPill(text: "94% match", tint: MarviColor.gold, systemImage: "star.fill")
                if isAccepted {
                    StatusPill(text: "Confirmed", tint: MarviColor.emerald, systemImage: "checkmark")
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(offer.capacity - offer.remaining) of \(offer.capacity) creator slots filled")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.78))

                    Spacer()

                    Text("\(offer.remaining) left")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(MarviColor.gold)
                }

                ProgressBar(value: Double(offer.capacity - offer.remaining) / Double(offer.capacity), tint: MarviColor.gold)
            }

            HStack(spacing: 10) {
                MetricPill(icon: "calendar", title: offer.dateLabel)
                MetricPill(icon: "clock", title: offer.timeLabel)
                MetricPill(icon: "gift", title: offer.valueLabel)
            }

            Button(action: open) {
                Label("View campaign brief", systemImage: "arrow.right.circle")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .foregroundStyle(MarviColor.ink)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(20)
        .background(
            ZStack {
                MarviGradient.brand
                MarviGradient.warm.opacity(0.8)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: Color.black.opacity(0.18), radius: 26, x: 0, y: 14)
    }
}

private struct MetricPill: View {
    let icon: String
    let title: String

    var body: some View {
        Label(title, systemImage: icon)
            .font(.caption.weight(.bold))
            .lineLimit(1)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.white.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct QuickMarketBar: View {
    var body: some View {
        HStack(spacing: 10) {
            MetricTile(value: "42", label: "venues", icon: "building.2", tint: MarviColor.emerald)
            MetricTile(value: "128", label: "creators", icon: "person.2", tint: MarviColor.aubergine)
            MetricTile(value: "96%", label: "proof", icon: "checkmark.seal", tint: MarviColor.blue)
        }
    }
}

private struct CollaborationModelStrip: View {
    @Binding var selectedModel: CollaborationModel?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ModelChip(title: "All models", icon: "square.grid.2x2", isSelected: selectedModel == nil) {
                    selectedModel = nil
                }
                ForEach(CollaborationModel.allCases) { model in
                    ModelChip(title: model.rawValue, icon: model.icon, isSelected: selectedModel == model) {
                        selectedModel = model
                    }
                }
            }
        }
    }
}

private struct ModelChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .foregroundStyle(isSelected ? .white : MarviColor.ink)
                .background(isSelected ? MarviColor.emerald : Color.white)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(Color.black.opacity(0.06), lineWidth: isSelected ? 0 : 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct FilterStrip: View {
    @Binding var selectedFilter: OfferFilter

    var body: some View {
        Picker("Offer filter", selection: $selectedFilter) {
            ForEach(OfferFilter.allCases) { filter in
                Text(filter.rawValue).tag(filter)
            }
        }
        .pickerStyle(.segmented)
    }
}

private struct CategorySelector: View {
    @Binding var selectedCategory: OfferCategory?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                CategoryChip(
                    title: "All",
                    icon: "square.grid.2x2",
                    isSelected: selectedCategory == nil,
                    tint: MarviColor.ink
                ) {
                    selectedCategory = nil
                }

                ForEach(OfferCategory.allCases) { category in
                    CategoryChip(
                        title: category.rawValue,
                        icon: category.icon,
                        isSelected: selectedCategory == category,
                        tint: category.tint
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }
}

private struct CategoryChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .foregroundStyle(isSelected ? .white : tint)
                .background(isSelected ? tint : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(tint.opacity(isSelected ? 0 : 0.16), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct OfferCard: View {
    let offer: Offer
    let isAccepted: Bool
    let isSaved: Bool
    let open: () -> Void

    var body: some View {
        MarviCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        MarviGradient.cool
                        Image(systemName: offer.imageName)
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(offer.category.tint)
                    }
                    .frame(width: 78, height: 86)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 7) {
                        HStack(spacing: 6) {
                            StatusPill(text: offer.category.rawValue, tint: offer.category.tint, systemImage: offer.category.icon)
                            StatusPill(text: offer.collaborationModel.rawValue, tint: MarviColor.gold, systemImage: offer.collaborationModel.icon)

                            if isAccepted {
                                StatusPill(text: "Confirmed", tint: MarviColor.emerald, systemImage: "checkmark")
                            }
                        }

                        Text(offer.title)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(MarviColor.ink)
                            .fixedSize(horizontal: false, vertical: true)

                        Label("\(offer.venue) - \(offer.area)", systemImage: "mappin.and.ellipse")
                            .font(.subheadline)
                            .foregroundStyle(MarviColor.muted)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(isSaved ? MarviColor.gold : MarviColor.muted)
                        .frame(width: 36, height: 36)
                        .background(MarviColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                HStack(spacing: 10) {
                    InfoBadge(icon: "calendar", text: offer.dateLabel)
                    InfoBadge(icon: "clock", text: offer.timeLabel)
                    InfoBadge(icon: "person.2", text: "\(offer.remaining) left")
                }

                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text(offer.valueLabel)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(MarviColor.ink)

                        Spacer()

                        Text("\(Int(fillRatio * 100))% filled")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(MarviColor.muted)
                    }

                    ProgressBar(value: fillRatio, tint: offer.category.tint)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: open)
    }

    private var fillRatio: Double {
        Double(offer.capacity - offer.remaining) / Double(offer.capacity)
    }
}
