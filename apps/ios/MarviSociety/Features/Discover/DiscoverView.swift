import SwiftUI

private enum OfferFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case saved = "Saved"
    case urgent = "Few slots"

    var id: String { rawValue }
}

private enum DiscoverMode: String, CaseIterable {
    case list = "List"
    case map = "Map"
}

private enum DiscoverSort: String, CaseIterable {
    case newest = "Newest"
    case slots = "Few slots"
    case match = "Best match"
}

struct DiscoverView: View {
    @EnvironmentObject private var appState: AppState
    @State private var discoverMode: DiscoverMode = .list
    @State private var selectedCategory: OfferCategory?
    @State private var selectedModel: CollaborationModel?
    @State private var selectedFilter: OfferFilter = .all
    @State private var selectedWhen: String?
    @State private var selectedWhere: String?
    @State private var selectedEventType: String?
    @State private var selectedCalendarDay: Int?
    @State private var searchText = ""
    @State private var selectedOffer: Offer?
    @State private var isShowingInbox = false
    @State private var sortMode: DiscoverSort = .newest
    @State private var isShowingSortMenu = false

    private let whenOptions = ["Tonight", "This week", "Weekend"]
    private let eventTypes = ["Dining", "Nightlife", "Wellness", "Beauty"]

    private var cityLabel: String {
        let city = appState.profile.city.trimmingCharacters(in: .whitespacesAndNewlines)
        return city.isEmpty ? "Your city" : city
    }

    private var whereOptions: [String] {
        let areas = Set(appState.offers.map(\.area).filter { !$0.isEmpty })
        return areas.isEmpty ? ["Karaköy", "Nişantaşı", "Kadıköy"] : Array(areas).sorted()
    }

    private var calendarDays: [CalendarDay] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE"
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "d"

        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: Date())) else {
                return nil
            }
            return CalendarDay(
                id: offset,
                weekday: formatter.string(from: date),
                label: dayFormatter.string(from: date),
                date: date
            )
        }
    }

    private var filteredOffers: [Offer] {
        appState.offers.filter { offer in
            let matchesCategory = selectedCategory == nil || offer.category == selectedCategory
            let matchesModel = selectedModel == nil || offer.collaborationModel == selectedModel
            let matchesSearch = searchText.isEmpty ||
                offer.title.localizedCaseInsensitiveContains(searchText) ||
                offer.venue.localizedCaseInsensitiveContains(searchText) ||
                offer.area.localizedCaseInsensitiveContains(searchText)
            let matchesWhere = selectedWhere == nil || offer.area.localizedCaseInsensitiveContains(selectedWhere!)
            let matchesType = selectedEventType == nil || offer.category.rawValue.localizedCaseInsensitiveContains(selectedEventType!)
            let matchesWhen = matchesWhenFilter(offer: offer, selection: selectedWhen)
            let matchesDay = matchesCalendarDay(offer: offer, dayIndex: selectedCalendarDay)
            let matchesFilter: Bool

            switch selectedFilter {
            case .all: matchesFilter = true
            case .saved: matchesFilter = appState.isSaved(offer)
            case .urgent: matchesFilter = offer.remaining <= 4
            }

            return matchesCategory && matchesModel && matchesSearch && matchesWhere && matchesType && matchesWhen && matchesDay && matchesFilter
        }
        .sorted(by: sortComparator)
    }

    private func sortComparator(_ lhs: Offer, _ rhs: Offer) -> Bool {
        switch sortMode {
        case .newest:
            return lhs.title < rhs.title
        case .slots:
            return lhs.remaining < rhs.remaining
        case .match:
            return lhs.remaining > rhs.remaining
        }
    }

    private func matchesWhenFilter(offer: Offer, selection: String?) -> Bool {
        guard let selection else { return true }
        let label = offer.dateLabel.lowercased()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        switch selection {
        case "Tonight":
            if label.contains("tonight") || label.contains("today") { return true }
            let weekday = calendar.component(.weekday, from: today)
            let symbols = calendar.shortWeekdaySymbols.map { $0.lowercased() }
            let todayName = symbols[weekday - 1]
            return label.contains(todayName)
        case "This week":
            return calendarDays.contains { day in
                label.contains(day.label) || label.contains(day.weekday.lowercased())
            }
        case "Weekend":
            return label.contains("sat") || label.contains("sun") || label.contains("weekend")
        default:
            return true
        }
    }

    private func matchesCalendarDay(offer: Offer, dayIndex: Int?) -> Bool {
        guard let dayIndex, let day = calendarDays[safe: dayIndex] else { return true }
        let label = offer.dateLabel.lowercased()
        return label.contains(day.label) || label.contains(day.weekday.lowercased())
    }

    private var featuredOffer: Offer? {
        filteredOffers.first ?? appState.offers.first
    }

    private var firstName: String {
        appState.profile.displayName
    }

    var body: some View {
        NavigationStack {
            MarviScreen {
                if discoverMode == .map {
                    MapDiscoverView()
                        .environmentObject(appState)
                } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        HomeHeader(
                            greeting: firstName,
                            subtitle: "\(cityLabel) · Private access",
                            onSearch: {},
                            onNotifications: { isShowingInbox = true }
                        )
                        .padding(.top, 4)

                        if appState.profile.status != .approved {
                            MembershipStatusBanner(status: appState.profile.status)
                        }

                        SSExploreHeader(city: cityLabel, eventCount: filteredOffers.count)

                        SSDiscoverAxisPills(
                            whenOptions: whenOptions,
                            whereOptions: whereOptions,
                            eventTypes: eventTypes,
                            selectedWhen: $selectedWhen,
                            selectedWhere: $selectedWhere,
                            selectedEventType: $selectedEventType
                        )

                        SSFilterToolbar(
                            onFilters: {
                                selectedFilter = selectedFilter == .all ? .saved : .all
                            },
                            onSort: { isShowingSortMenu = true },
                            onLocation: { selectedWhere = whereOptions.first },
                            onDate: { selectedCalendarDay = 0 }
                        )
                        .confirmationDialog("Sort events", isPresented: $isShowingSortMenu, titleVisibility: .visible) {
                            ForEach(DiscoverSort.allCases, id: \.self) { mode in
                                Button(mode.rawValue) { sortMode = mode }
                            }
                        }

                        SSSegmentedTabs(
                            options: DiscoverMode.allCases,
                            title: { $0.rawValue },
                            selection: $discoverMode
                        )

                        if !filteredOffers.isEmpty {
                            SSFeaturedEventsCarousel(title: "Featured Events") {
                                ForEach(filteredOffers.prefix(5)) { offer in
                                    FeaturedEventCompact(
                                        offer: offer,
                                        open: { selectedOffer = offer }
                                    )
                                }
                            }
                        }

                        if let featuredOffer {
                            FeaturedEventHero(
                                offer: featuredOffer,
                                matchScore: appState.profile.score,
                                isSaved: appState.isSaved(featuredOffer),
                                open: { selectedOffer = featuredOffer },
                                toggleSaved: { appState.toggleSaved(featuredOffer) }
                            )
                        }

                        EventCalendarStrip(selectedDay: $selectedCalendarDay, days: calendarDays)

                        FilterPillRow(
                            items: OfferFilter.allCases.map(\.rawValue),
                            selected: Binding(
                                get: { selectedFilter == .all ? nil : selectedFilter.rawValue },
                                set: { newValue in
                                    if let newValue,
                                       let filter = OfferFilter.allCases.first(where: { $0.rawValue == newValue }) {
                                        selectedFilter = filter
                                    } else {
                                        selectedFilter = .all
                                    }
                                }
                            )
                        )

                        CollaborationModelStrip(selectedModel: $selectedModel)

                        if appState.isSyncing && appState.offers.isEmpty {
                            OfferListSkeleton()
                        } else if filteredOffers.isEmpty {
                            MarviCard {
                                EmptyStateView(
                                    title: appState.isSyncing ? "Loading events…" : "No events yet",
                                    subtitle: appState.isSyncing
                                        ? "Fetching live campaigns from the server."
                                        : "New venue invitations appear here when published for \(cityLabel). Pull down to refresh.",
                                    icon: "calendar.badge.clock",
                                    actionTitle: appState.isSyncing ? nil : "Refresh",
                                    action: appState.isSyncing ? nil : { Task { await appState.refreshFromServer() } }
                                )
                            }
                        } else {
                            LazyVStack(spacing: 14) {
                                ForEach(filteredOffers) { offer in
                                    EventListCard(
                                        offer: offer,
                                        isSaved: appState.isSaved(offer),
                                        isAccepted: appState.isAccepted(offer),
                                        open: { selectedOffer = offer },
                                        toggleSaved: { appState.toggleSaved(offer) }
                                    )
                                }
                            }
                        }
                    }
                    .padding(16)
                }
                .refreshable {
                    await appState.refreshFromServer()
                }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .searchable(text: $searchText, prompt: "Venue, area, category")
            .navigationDestination(item: $selectedOffer) { offer in
                OfferDetailView(offer: offer)
            }
            .sheet(isPresented: $isShowingInbox) {
                NavigationStack {
                    InboxView()
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") { isShowingInbox = false }
                            }
                        }
                }
            }
        }
    }
}

private struct FeaturedEventCompact: View {
    let offer: Offer
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 0) {
                OfferImageView(offer: offer, height: 120, cornerRadius: 0)
                    .frame(width: 200, height: 120)
                    .clipped()

                VStack(alignment: .leading, spacing: 4) {
                    Text(offer.venue.uppercased())
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(MarviColor.rose)
                    Text(offer.title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(MarviColor.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .padding(10)
                .frame(width: 200, alignment: .leading)
                .background(MarviColor.panel)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(MarviColor.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct FeaturedEventHero: View {
    let offer: Offer
    let matchScore: Int
    let isSaved: Bool
    let open: () -> Void
    let toggleSaved: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                OfferImageView(offer: offer, height: 200)

                MarviGradient.heroOverlay
                    .frame(height: 200)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Featured Event")
                        .font(.caption.weight(.bold))
                        .textCase(.uppercase)
                        .foregroundStyle(MarviColor.rose)

                    Text(offer.title)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                }
                .padding(16)
            }

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    StatusPill(text: offer.category.rawValue, tint: MarviColor.rose, systemImage: offer.category.icon)
                    if matchScore > 0 {
                        StatusPill(text: "\(matchScore)% match", tint: MarviColor.gold, systemImage: "star.fill")
                    }
                    Spacer()
                    Button(action: toggleSaved) {
                        Image(systemName: isSaved ? "heart.fill" : "heart")
                            .foregroundStyle(isSaved ? MarviColor.rose : MarviColor.muted)
                    }
                    .buttonStyle(.plain)
                }

                Label("\(offer.venue) · \(offer.area)", systemImage: "mappin.and.ellipse")
                    .font(.subheadline)
                    .foregroundStyle(MarviColor.graphite)

                HStack(spacing: 10) {
                    InfoBadge(icon: "calendar", text: offer.dateLabel)
                    InfoBadge(icon: "clock", text: offer.timeLabel)
                    InfoBadge(icon: "gift", text: offer.valueLabel)
                }

                GradientCTA(title: "View event brief", action: open)
            }
            .padding(16)
            .background(MarviColor.panel)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(MarviColor.border, lineWidth: 1)
        )
    }
}

private struct EventListCard: View {
    let offer: Offer
    let isSaved: Bool
    let isAccepted: Bool
    let open: () -> Void
    let toggleSaved: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: 14) {
                OfferImageView(offer: offer, height: 80, cornerRadius: 14)
                    .frame(width: 72, height: 80)

                VStack(alignment: .leading, spacing: 6) {
                    Text(offer.venue.uppercased())
                        .font(.caption2.weight(.bold))
                        .tracking(1)
                        .foregroundStyle(MarviColor.rose)

                    Text(offer.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(MarviColor.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 8) {
                        Label(offer.dateLabel, systemImage: "calendar")
                        if isAccepted {
                            StatusPill(text: "Confirmed", tint: MarviColor.emerald, systemImage: "checkmark")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(MarviColor.muted)
                }

                Spacer(minLength: 0)

                Button(action: toggleSaved) {
                    Image(systemName: isSaved ? "heart.fill" : "heart")
                        .foregroundStyle(isSaved ? MarviColor.rose : MarviColor.muted)
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(MarviColor.panel)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(MarviColor.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct CollaborationModelStrip: View {
    @Binding var selectedModel: CollaborationModel?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ModelChip(title: "All", icon: "square.grid.2x2", isSelected: selectedModel == nil) {
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

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
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
                .background(isSelected ? AnyShapeStyle(MarviGradient.brand) : AnyShapeStyle(MarviColor.panel))
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(MarviColor.border, lineWidth: isSelected ? 0 : 1)
                )
        }
        .buttonStyle(.plain)
    }
}
