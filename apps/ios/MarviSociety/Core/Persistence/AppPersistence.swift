import Foundation

/// Local preferences only — server data is always loaded from Supabase.
struct AppSnapshot: Codable {
    var hasCompletedOnboarding: Bool
    var selectedRole: UserRole
    var pushNotificationsEnabled: Bool
    var proofRemindersEnabled: Bool
    var autoSaveProofLinks: Bool
}

final class AppPersistence {
    static let shared = AppPersistence()

    private let snapshotKey = "marviSociety.appSnapshot.v2"
    private let legacySnapshotKey = "marviSociety.appSnapshot.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> AppSnapshot? {
        if let data = defaults.data(forKey: snapshotKey),
           let snapshot = try? JSONDecoder().decode(AppSnapshot.self, from: data) {
            return snapshot
        }
        return migrateLegacySnapshot()
    }

    func save(_ snapshot: AppSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: snapshotKey)
    }

    func reset() {
        defaults.removeObject(forKey: snapshotKey)
        defaults.removeObject(forKey: legacySnapshotKey)
    }

    private func migrateLegacySnapshot() -> AppSnapshot? {
        guard let data = defaults.data(forKey: legacySnapshotKey),
              let legacy = try? JSONDecoder().decode(LegacyAppSnapshot.self, from: data) else {
            return nil
        }
        defaults.removeObject(forKey: legacySnapshotKey)
        let snapshot = AppSnapshot(
            hasCompletedOnboarding: legacy.hasCompletedOnboarding,
            selectedRole: legacy.selectedRole,
            pushNotificationsEnabled: legacy.pushNotificationsEnabled,
            proofRemindersEnabled: legacy.proofRemindersEnabled,
            autoSaveProofLinks: legacy.autoSaveProofLinks
        )
        save(snapshot)
        return snapshot
    }
}

private struct LegacyAppSnapshot: Codable {
    var hasCompletedOnboarding: Bool
    var selectedRole: UserRole
    var pushNotificationsEnabled: Bool
    var proofRemindersEnabled: Bool
    var autoSaveProofLinks: Bool
}
