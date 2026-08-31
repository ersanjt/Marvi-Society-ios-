import SwiftUI
import UserNotifications

final class MarviAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        NotificationCenter.default.post(
            name: .marviDidRegisterPushToken,
            object: nil,
            userInfo: ["token": deviceToken]
        )
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        #if DEBUG
        print("[Push] remote registration failed: \(error.localizedDescription)")
        #endif
    }
}

extension MarviAppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        NotificationCenter.default.post(
            name: .marviDidReceivePush,
            object: nil,
            userInfo: notification.request.content.userInfo
        )
        return [.banner, .sound, .badge]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        NotificationCenter.default.post(
            name: .marviDidTapPush,
            object: nil,
            userInfo: response.notification.request.content.userInfo
        )
    }
}

extension Notification.Name {
    static let marviDidRegisterPushToken = Notification.Name("marviDidRegisterPushToken")
    static let marviDidReceivePush = Notification.Name("marviDidReceivePush")
    static let marviDidTapPush = Notification.Name("marviDidTapPush")
}
