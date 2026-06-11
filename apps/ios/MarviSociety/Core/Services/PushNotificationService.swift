import Foundation
import UserNotifications

enum PushNotificationService {
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    static func scheduleProofReminder(for booking: Booking, enabled: Bool) {
        let center = UNUserNotificationCenter.current()
        let identifier = "proof-\(booking.id.uuidString)"

        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        guard enabled, booking.proofStatus == .notStarted || booking.proofStatus == .pending else { return }

        let content = UNMutableNotificationContent()
        content.title = "Proof reminder"
        content.body = "Submit your content links for \(booking.offer.venue) before \(booking.proofDeadline)."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60 * 60 * 4, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
    }

    static func cancelAllProofReminders() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let proofIDs = requests
                .map(\.identifier)
                .filter { $0.hasPrefix("proof-") }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: proofIDs)
        }
    }

    static func scheduleInstantOfferNearby(venueName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Instant offer nearby"
        content.body = "\(venueName) has a walk-in collaboration open near you."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(
            identifier: "instant-nearby-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }
}
