import Foundation

/// Local preferences only — server data is always loaded from Supabase.
struct AppSnapshot: Codable {
    var hasCompletedOnboarding: Bool
    var selectedRole: UserRole
    var pushNotificationsEnabled: Bool
    var proofRemindersEnabled: Bool
    var autoSaveProofLinks: Bool
    var preferredLanguage: AppLanguage
    var languageManuallySet: Bool

    init(
        hasCompletedOnboarding: Bool,
        selectedRole: UserRole,
        pushNotificationsEnabled: Bool,
        proofRemindersEnabled: Bool,
        autoSaveProofLinks: Bool,
        preferredLanguage: AppLanguage = AppLanguage.inferredFromDevice(),
        languageManuallySet: Bool = false
    ) {
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.selectedRole = selectedRole
        self.pushNotificationsEnabled = pushNotificationsEnabled
        self.proofRemindersEnabled = proofRemindersEnabled
        self.autoSaveProofLinks = autoSaveProofLinks
        self.preferredLanguage = preferredLanguage
        self.languageManuallySet = languageManuallySet
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hasCompletedOnboarding = try container.decode(Bool.self, forKey: .hasCompletedOnboarding)
        selectedRole = try container.decode(UserRole.self, forKey: .selectedRole)
        pushNotificationsEnabled = try container.decode(Bool.self, forKey: .pushNotificationsEnabled)
        proofRemindersEnabled = try container.decode(Bool.self, forKey: .proofRemindersEnabled)
        autoSaveProofLinks = try container.decode(Bool.self, forKey: .autoSaveProofLinks)
        languageManuallySet = try container.decodeIfPresent(Bool.self, forKey: .languageManuallySet) ?? false
        preferredLanguage = try container.decodeIfPresent(AppLanguage.self, forKey: .preferredLanguage)
            ?? AppLanguage.inferredFromDevice()
    }
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
            autoSaveProofLinks: legacy.autoSaveProofLinks,
            preferredLanguage: AppLanguage.inferredFromDevice()
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
