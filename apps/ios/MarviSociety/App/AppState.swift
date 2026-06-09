import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var hasCompletedOnboarding = false {
        didSet { saveSnapshot() }
    }
    @Published var selectedRole: UserRole = .creator {
        didSet { saveSnapshot() }
    }
    @Published var offers: [Offer] = SampleData.offers
    @Published var savedOfferIDs: Set<UUID> = [SampleData.offers[0].id, SampleData.offers[2].id] {
        didSet { saveSnapshot() }
    }
    @Published var bookings: [Booking] = SampleData.bookings {
        didSet { saveSnapshot() }
    }
    @Published var campaigns: [Campaign] = SampleData.campaigns {
        didSet { saveSnapshot() }
    }
    @Published var adminTasks: [AdminTask] = SampleData.adminTasks {
        didSet { saveSnapshot() }
    }
    @Published var inboxMessages: [InboxMessage] = SampleData.inboxMessages {
        didSet { saveSnapshot() }
    }
    @Published var profile = SampleData.profile {
        didSet { saveSnapshot() }
    }
    @Published var pushNotificationsEnabled = true {
        didSet { saveSnapshot() }
    }
    @Published var proofRemindersEnabled = true {
        didSet { saveSnapshot() }
    }
    @Published var autoSaveProofLinks = true {
        didSet { saveSnapshot() }
    }

    @Published var isSyncing = false
    @Published var lastSyncError: String?
    @Published var isAuthenticated = false

    let isRemoteMode: Bool
    private let api: any MarviAPI
    private let persistence: AppPersistence
    private var isPersistenceReady = false

    init(persistence: AppPersistence = .shared, api: (any MarviAPI)? = nil) {
        self.persistence = persistence
        self.api = api ?? APIConfig.makeAPI()
        self.isRemoteMode = self.api.usesRemoteBackend

        if let snapshot = persistence.load() {
            hasCompletedOnboarding = snapshot.hasCompletedOnboarding
            selectedRole = snapshot.selectedRole
            savedOfferIDs = snapshot.savedOfferIDs
            bookings = snapshot.bookings
            campaigns = snapshot.campaigns
            adminTasks = snapshot.adminTasks
            inboxMessages = snapshot.inboxMessages
            profile = snapshot.profile
            pushNotificationsEnabled = snapshot.pushNotificationsEnabled
            proofRemindersEnabled = snapshot.proofRemindersEnabled
            autoSaveProofLinks = snapshot.autoSaveProofLinks
        }

        isPersistenceReady = true

        if isRemoteMode && hasCompletedOnboarding {
            Task { await refreshFromServer() }
        }
    }

    var acceptedOfferIDs: Set<UUID> {
        Set(bookings.filter { $0.stage != .cancelled }.map(\.offer.id))
    }

    var activeBookings: [Booking] {
        bookings.filter { $0.stage != .cancelled }
    }

    var openAdminTasks: [AdminTask] {
        adminTasks.filter { $0.status == .open }
    }

    var backendLabel: String {
        isRemoteMode ? "Supabase" : "Local demo"
    }

    // MARK: - Sync

    func refreshFromServer() async {
        guard isRemoteMode else { return }
        isSyncing = true
        lastSyncError = nil
        defer { isSyncing = false }

        do {
            async let offersTask = api.fetchOffers(city: profile.city.lowercased())
            async let bookingsTask = api.fetchBookings()
            async let profileTask = api.fetchProfile()
            async let inboxTask = api.fetchNotifications()
            async let savedTask = api.fetchSavedOfferIDs()
            async let tasksTask = api.fetchAdminTasks()

            offers = try await offersTask
            bookings = try await bookingsTask
            profile = try await profileTask
            inboxMessages = try await inboxTask
            savedOfferIDs = try await savedTask
            adminTasks = try await tasksTask
            isAuthenticated = await api.accessToken != nil
        } catch {
            lastSyncError = error.localizedDescription
        }
    }

    func signInWithApple(using service: AppleSignInService, metadata: [String: String]) async {
        guard isRemoteMode else {
            completeOnboarding(role: selectedRole)
            return
        }

        isSyncing = true
        lastSyncError = nil
        defer { isSyncing = false }

        do {
            let tokens = try await service.signIn()
            try await api.signInWithApple(
                idToken: tokens.idToken,
                nonce: tokens.nonce,
                metadata: metadata
            )
            isAuthenticated = true
            await refreshFromServer()
        } catch {
            lastSyncError = error.localizedDescription
        }
    }

    // MARK: - Onboarding

    func completeOnboarding(role: UserRole) {
        selectedRole = role
        hasCompletedOnboarding = true
        inboxMessages.insert(
            InboxMessage(
                title: "Welcome to Marvi Society",
                body: "Your Istanbul workspace is ready. Backend: \(backendLabel).",
                dateLabel: "Now",
                icon: "sparkles",
                tint: .emerald
            ),
            at: 0
        )

        if isRemoteMode {
            Task { await refreshFromServer() }
        }
    }

    // MARK: - Offers

    func isAccepted(_ offer: Offer) -> Bool {
        acceptedOfferIDs.contains(offer.id)
    }

    func isSaved(_ offer: Offer) -> Bool {
        savedOfferIDs.contains(offer.id)
    }

    func toggleSaved(_ offer: Offer) {
        if isRemoteMode {
            Task {
                do {
                    let saved = try await api.toggleSavedOffer(offer.id)
                    if saved {
                        savedOfferIDs.insert(offer.id)
                    } else {
                        savedOfferIDs.remove(offer.id)
                    }
                } catch {
                    lastSyncError = error.localizedDescription
                }
            }
            return
        }

        if savedOfferIDs.contains(offer.id) {
            savedOfferIDs.remove(offer.id)
        } else {
            savedOfferIDs.insert(offer.id)
        }
    }

    func accept(_ offer: Offer) {
        guard !isAccepted(offer) else { return }

        if isRemoteMode {
            Task {
                do {
                    let booking = try await api.acceptOffer(offer.id)
                    bookings.insert(booking, at: 0)
                    await refreshFromServer()
                } catch {
                    lastSyncError = error.localizedDescription
                }
            }
            return
        }

        bookings.insert(
            Booking(
                id: UUID(),
                offer: offer,
                stage: .confirmed,
                proofDeadline: "\(offer.dateLabel), 22:00",
                checklist: [
                    "Confirm guest details",
                    "Check in with venue host",
                    "Upload story, post, or review links"
                ],
                proofStatus: .notStarted,
                checkInCode: String(Int.random(in: 1200...9899)),
                guestName: "",
                proofLinks: []
            ),
            at: 0
        )

        inboxMessages.insert(
            InboxMessage(
                title: "Invitation confirmed",
                body: "\(offer.venue) is now in your bookings. Your check-in code is available in the booking card.",
                dateLabel: "Now",
                icon: "checkmark.circle.fill",
                tint: .emerald
            ),
            at: 0
        )
    }

    func cancel(_ offer: Offer) {
        if isRemoteMode {
            Task {
                do {
                    try await api.cancelOffer(offer.id)
                    await refreshFromServer()
                } catch {
                    lastSyncError = error.localizedDescription
                }
            }
            return
        }

        for index in bookings.indices where bookings[index].offer.id == offer.id {
            bookings[index].stage = .cancelled
        }
    }

    func checkIn(_ booking: Booking) {
        if isRemoteMode {
            Task {
                do {
                    let updated = try await api.checkIn(bookingID: booking.id, code: booking.checkInCode)
                    updateBooking(updated.id) { $0 = updated }
                } catch {
                    lastSyncError = error.localizedDescription
                }
            }
            return
        }

        updateBooking(booking.id) { booking in
            booking.stage = .checkedIn
        }
    }

    func submitProof(for booking: Booking, links: [String]) {
        if isRemoteMode {
            Task {
                do {
                    let updated = try await api.submitProof(bookingID: booking.id, links: links)
                    updateBooking(updated.id) { $0 = updated }
                    await refreshFromServer()
                } catch {
                    lastSyncError = error.localizedDescription
                }
            }
            return
        }

        updateBooking(booking.id) { booking in
            booking.stage = .completed
            booking.proofStatus = .pending
            booking.proofLinks = links
        }

        adminTasks.insert(
            AdminTask(
                type: .proofReview,
                title: "\(booking.offer.venue) proof",
                subtitle: "\(profile.name) submitted \(links.count) proof link(s).",
                dateLabel: "Now",
                priority: "Medium"
            ),
            at: 0
        )

        inboxMessages.insert(
            InboxMessage(
                title: "Proof sent to review",
                body: "Admin will review your submission for \(booking.offer.venue).",
                dateLabel: "Now",
                icon: "tray.and.arrow.up.fill",
                tint: .blue
            ),
            at: 0
        )
    }

    func createCampaign(
        title: String,
        venueName: String,
        area: String,
        category: OfferCategory,
        dateLabel: String,
        valueLabel: String,
        slots: Int,
        deliverables: [String]
    ) {
        let campaign = Campaign(
            title: title,
            venueName: venueName,
            area: area,
            category: category,
            dateLabel: dateLabel,
            valueLabel: valueLabel,
            slots: slots,
            matchedCreators: 0,
            status: .review,
            deliverables: deliverables
        )

        campaigns.insert(campaign, at: 0)
        adminTasks.insert(
            AdminTask(
                type: .campaignReview,
                title: campaign.title,
                subtitle: "\(campaign.venueName) requested \(campaign.slots) creator slots.",
                dateLabel: "Now",
                priority: "High"
            ),
            at: 0
        )
    }

    func approveTask(_ task: AdminTask) {
        if isRemoteMode {
            Task {
                do {
                    try await api.approveTask(task.id)
                    await refreshFromServer()
                } catch {
                    lastSyncError = error.localizedDescription
                }
            }
            return
        }

        setTask(task, status: .approved)
        inboxMessages.insert(
            InboxMessage(
                title: "Admin approved: \(task.type.rawValue)",
                body: task.title,
                dateLabel: "Now",
                icon: "checkmark.shield.fill",
                tint: .emerald
            ),
            at: 0
        )
    }

    func rejectTask(_ task: AdminTask) {
        if isRemoteMode {
            Task {
                do {
                    try await api.rejectTask(task.id)
                    await refreshFromServer()
                } catch {
                    lastSyncError = error.localizedDescription
                }
            }
            return
        }

        setTask(task, status: .rejected)
    }

    func resetDemoData() {
        isPersistenceReady = false
        hasCompletedOnboarding = false
        selectedRole = .creator
        offers = SampleData.offers
        savedOfferIDs = [SampleData.offers[0].id, SampleData.offers[2].id]
        bookings = SampleData.bookings
        campaigns = SampleData.campaigns
        adminTasks = SampleData.adminTasks
        inboxMessages = SampleData.inboxMessages
        profile = SampleData.profile
        pushNotificationsEnabled = true
        proofRemindersEnabled = true
        autoSaveProofLinks = true
        lastSyncError = nil
        isAuthenticated = false
        persistence.reset()
        isPersistenceReady = true

        if isRemoteMode {
            Task {
                try? await api.signOut()
            }
        }
    }

    private func updateBooking(_ id: UUID, update: (inout Booking) -> Void) {
        guard let index = bookings.firstIndex(where: { $0.id == id }) else { return }
        update(&bookings[index])
    }

    private func setTask(_ task: AdminTask, status: AdminTaskStatus) {
        guard let index = adminTasks.firstIndex(where: { $0.id == task.id }) else { return }
        adminTasks[index].status = status
    }

    private func saveSnapshot() {
        guard isPersistenceReady else { return }
        persistence.save(
            AppSnapshot(
                hasCompletedOnboarding: hasCompletedOnboarding,
                selectedRole: selectedRole,
                savedOfferIDs: savedOfferIDs,
                bookings: bookings,
                campaigns: campaigns,
                adminTasks: adminTasks,
                inboxMessages: inboxMessages,
                profile: profile,
                pushNotificationsEnabled: pushNotificationsEnabled,
                proofRemindersEnabled: proofRemindersEnabled,
                autoSaveProofLinks: autoSaveProofLinks
            )
        )
    }
}
