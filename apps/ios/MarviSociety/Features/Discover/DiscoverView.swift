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

    private var whenOptions: [String] {
        [appState.t(.tonight), appState.t(.thisWeek), appState.t(.weekend)]
    }

    private var eventTypes: [String] {
        OfferCategory.allCases.map { $0.label(for: appState.preferredLanguage) }
    }

    private var cityLabel: String {
        let city = appState.profile.city.trimmingCharacters(in: .whitespacesAndNewlines)
        return city.isEmpty ? appState.t(.yourCity) : city
    }

    private var whereOptions: [String] {
        let areas = Set(appState.offers.map(\.area).filter { !$0.isEmpty })
        return areas.isEmpty ? ["Karaköy", "Nişantaşı", "Kadıköy"] : Array(areas).sorted()
    }

    private var calendarDays: [CalendarDay] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: appState.preferredLanguage == .turkish ? "tr_TR" : "en_US_POSIX")
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
            let matchesType = selectedEventType == nil || offer.category.label(for: appState.preferredLanguage).localizedCaseInsensitiveContains(selectedEventType!)
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
            return lhs.sortDate > rhs.sortDate
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
        case appState.t(.tonight):
            if label.contains("tonight") || label.contains("today") || label.contains("bu gece") || label.contains("bugün") { return true }
            let weekday = calendar.component(.weekday, from: today)
            let symbols = calendar.shortWeekdaySymbols.map { $0.lowercased() }
            let todayName = symbols[weekday - 1]
            return label.contains(todayName)
        case appState.t(.thisWeek):
            return calendarDays.contains { day in
                label.contains(day.label) || label.contains(day.weekday.lowercased())
            }
        case appState.t(.weekend):
            return label.contains("sat") || label.contains("sun") || label.contains("weekend")
                || label.contains("cum") || label.contains("paz")
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
                    MapDiscoverView {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                            discoverMode = .list
                        }
                    }
                        .environmentObject(appState)
                } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        HomeHeader(
                            greeting: firstName,
                            subtitle: "\(cityLabel) · \(appState.t(.privateAccess))",
                            onNotifications: { isShowingInbox = true }
                        )
                        .padding(.top, 4)

                        if appState.profile.status != .approved {
                            MembershipStatusBanner(
                                status: appState.profile.status,
                                language: appState.preferredLanguage,
                                pausedBySelf: appState.accountPausedBySelf,
                                onReactivate: {
                                    Task { _ = await appState.reactivateAccount() }
                                }
                            )
                        }

                        SSExploreHeader(city: cityLabel, eventCount: filteredOffers.count, language: appState.preferredLanguage)

                        SSDiscoverAxisPills(
                            whenOptions: whenOptions,
                            whereOptions: whereOptions,
                            eventTypes: eventTypes,
                            language: appState.preferredLanguage,
                            selectedWhen: $selectedWhen,
                            selectedWhere: $selectedWhere,
                            selectedEventType: $selectedEventType
                        )

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(OfferCategory.allCases, id: \.self) { category in
                                    SSFilterChip(title: category.label(for: appState.preferredLanguage), icon: "tag") {
                                        selectedCategory = selectedCategory == category ? nil : category
                                    }
                                    .opacity(selectedCategory == nil || selectedCategory == category ? 1 : 0.45)
                                }
                            }
                        }

                        SSFilterToolbar(
                            language: appState.preferredLanguage,
                            onFilters: {
                                selectedFilter = selectedFilter == .all ? .saved : .all
                            },
                            onSort: { isShowingSortMenu = true },
                            onLocation: { selectedWhere = whereOptions.first },
                            onDate: { selectedCalendarDay = 0 }
                        )
                        .confirmationDialog(appState.t(.sortEvents), isPresented: $isShowingSortMenu, titleVisibility: .visible) {
                            Button(appState.t(.sortNewest)) { sortMode = .newest }
                            Button(appState.t(.sortFewSlots)) { sortMode = .slots }
                            Button(appState.t(.sortBestMatch)) { sortMode = .match }
                        }

                        SSSegmentedTabs(
                            options: DiscoverMode.allCases,
                            title: { mode in
                                mode == .list ? appState.t(.listMode) : appState.t(.mapMode)
                            },
                            selection: $discoverMode
                        )

                        if !filteredOffers.isEmpty {
                            SSFeaturedEventsCarousel(title: appState.t(.featuredEvents)) {
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
                            items: [
                                appState.t(.filterAll),
                                appState.t(.filterSaved),
                                appState.t(.filterFewSlots)
                            ],
                            selected: Binding(
                                get: {
                                    switch selectedFilter {
                                    case .all: return nil
                                    case .saved: return appState.t(.filterSaved)
                                    case .urgent: return appState.t(.filterFewSlots)
                                    }
                                },
                                set: { newValue in
                                    if newValue == appState.t(.filterSaved) {
                                        selectedFilter = .saved
                                    } else if newValue == appState.t(.filterFewSlots) {
                                        selectedFilter = .urgent
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
                                    title: appState.isSyncing ? appState.t(.loadingEvents) : appState.t(.noEventsYet),
                                    subtitle: appState.isSyncing
                                        ? appState.t(.fetchingLive)
                                        : String(format: appState.t(.newVenueInvites), cityLabel),
                                    icon: "calendar.badge.clock",
                                    actionTitle: appState.isSyncing ? nil : appState.t(.refresh),
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
            .searchable(text: $searchText, prompt: appState.t(.searchVenuePrompt))
            .navigationDestination(item: $selectedOffer) { offer in
                OfferDetailView(offer: offer)
            }
            .onChange(of: appState.pendingOfferNavigation?.id) { _, _ in
                if let offer = appState.pendingOfferNavigation {
                    selectedOffer = offer
                    appState.pendingOfferNavigation = nil
                }
            }
            .sheet(isPresented: $isShowingInbox) {
                NavigationStack {
                    InboxView()
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button(appState.t(.done)) { isShowingInbox = false }
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
    @EnvironmentObject private var appState: AppState
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
                    Text(appState.t(.featuredEvent))
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
                    StatusPill(text: offer.category.label(for: appState.preferredLanguage), tint: MarviColor.rose, systemImage: offer.category.icon)
                    if matchScore > 0 {
                        StatusPill(text: appState.tf(.matchPercent, matchScore), tint: MarviColor.gold, systemImage: "star.fill")
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

                GradientCTA(title: appState.t(.viewEventBrief), action: open)
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
    @EnvironmentObject private var appState: AppState
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
                            StatusPill(text: appState.t(.confirmedStatus), tint: MarviColor.emerald, systemImage: "checkmark")
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
    @EnvironmentObject private var appState: AppState
    @Binding var selectedModel: CollaborationModel?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ModelChip(title: appState.t(.filterAll), icon: "square.grid.2x2", isSelected: selectedModel == nil) {
                    selectedModel = nil
                }
                ForEach(CollaborationModel.allCases) { model in
                    ModelChip(title: model.label(for: appState.preferredLanguage), icon: model.icon, isSelected: selectedModel == model) {
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
