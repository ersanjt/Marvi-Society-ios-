import SwiftUI

@main
struct MarviSocietyApp: App {
    @UIApplicationDelegateAdaptor(MarviAppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .onReceive(NotificationCenter.default.publisher(for: .marviDidRegisterPushToken)) { notification in
                    if let token = notification.userInfo?["token"] as? Data {
                        appState.registerPushToken(token)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .marviDidReceivePush)) { _ in
                    appState.handlePushReceived()
                }
                .onReceive(NotificationCenter.default.publisher(for: .marviDidTapPush)) { notification in
                    appState.handlePushTapped(userInfo: notification.userInfo ?? [:])
                }
                .onOpenURL { url in
                    appState.handleDeepLinkURL(url)
                }
        }
    }
}
