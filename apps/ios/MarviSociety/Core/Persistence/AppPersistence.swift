import Foundation

struct AppSnapshot: Codable {
    var hasCompletedOnboarding: Bool
    var selectedRole: UserRole
    var savedOfferIDs: Set<UUID>
    var bookings: [Booking]
    var campaigns: [Campaign]
    var adminTasks: [AdminTask]
    var inboxMessages: [InboxMessage]
    var profile: CreatorProfile
    var pushNotificationsEnabled: Bool
    var proofRemindersEnabled: Bool
    var autoSaveProofLinks: Bool
}

final class AppPersistence {
    static let shared = AppPersistence()

    private let snapshotKey = "marviSociety.appSnapshot.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> AppSnapshot? {
        guard let data = defaults.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(AppSnapshot.self, from: data)
    }

    func save(_ snapshot: AppSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: snapshotKey)
    }

    func reset() {
        defaults.removeObject(forKey: snapshotKey)
    }
}
