import SwiftUI

struct MainAppShell: View {
    @EnvironmentObject private var appState: AppState

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.02, green: 0.02, blue: 0.03, alpha: 1)
        appearance.shadowColor = UIColor(red: 1, green: 0.18, blue: 0.47, alpha: 0.15)

        let normal = appearance.stackedLayoutAppearance.normal
        normal.iconColor = UIColor(white: 0.5, alpha: 1)
        normal.titleTextAttributes = [
            .foregroundColor: UIColor(white: 0.5, alpha: 1),
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold)
        ]

        let selected = appearance.stackedLayoutAppearance.selected
        selected.iconColor = UIColor(red: 1, green: 0.18, blue: 0.47, alpha: 1)
        selected.titleTextAttributes = [
            .foregroundColor: UIColor(red: 1, green: 0.18, blue: 0.47, alpha: 1),
            .font: UIFont.systemFont(ofSize: 10, weight: .bold)
        ]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        let lang = appState.preferredLanguage

        VStack(spacing: 0) {
            if let error = appState.lastSyncError {
                SyncErrorBanner(
                    message: error,
                    retryTitle: appState.t(.retry),
                    onRetry: { Task { await appState.refreshFromServer() } },
                    onDismiss: { appState.dismissSyncError() }
                )
            }

            TabView(selection: $appState.workspaceTabIndex) {
            switch appState.selectedRole {
            case .creator:
                DiscoverView()
                    .tabItem { Label(MarviL10n.t(.explore, language: lang), systemImage: "sparkles") }
                    .tag(0)

                BookingsView()
                    .tabItem { Label(MarviL10n.t(.myEvents, language: lang), systemImage: "calendar.badge.clock") }
                    .tag(1)

                ProfileView()
                    .tabItem {
                        Label(MarviL10n.t(.profile, language: lang), systemImage: "person.crop.circle.fill")
                    }
                    .badge(appState.unreadInboxCount > 0 ? appState.unreadInboxCount : 0)
                    .tag(2)

            case .venue:
                VenueStudioView()
                    .tabItem { Label(MarviL10n.t(.studio, language: lang), systemImage: "building.2") }
                    .tag(0)

                InboxView()
                    .tabItem { Label(MarviL10n.t(.inbox, language: lang), systemImage: "bell") }
                    .badge(appState.unreadInboxCount > 0 ? appState.unreadInboxCount : 0)
                    .tag(1)

                ProfileView()
                    .tabItem { Label(MarviL10n.t(.account, language: lang), systemImage: "person.crop.circle") }
                    .tag(2)

            case .admin:
                AdminDashboardView()
                    .tabItem { Label(MarviL10n.t(.admin, language: lang), systemImage: "checkmark.shield") }
                    .tag(0)

                InboxView()
                    .tabItem { Label(MarviL10n.t(.inbox, language: lang), systemImage: "bell") }
                    .badge(appState.unreadInboxCount > 0 ? appState.unreadInboxCount : 0)
                    .tag(1)

                ProfileView()
                    .tabItem { Label(MarviL10n.t(.account, language: lang), systemImage: "person.crop.circle") }
                    .tag(2)
            }
            }
            .id(appState.selectedRole)
            .tint(MarviColor.rose)
            .onChange(of: appState.selectedRole) { _, _ in
                appState.workspaceTabIndex = 0
            }
            .onChange(of: appState.locationService.coordinate?.latitude) { _, _ in
                appState.handleLocationUpdate()
            }
        }
        .fullScreenCover(isPresented: $appState.isPresentingAdminConsole) {
            NavigationStack {
                AdminDashboardView()
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button(appState.t(.close)) {
                                appState.isPresentingAdminConsole = false
                            }
                            .fontWeight(.semibold)
                        }
                    }
            }
            .environmentObject(appState)
        }
    }
}
