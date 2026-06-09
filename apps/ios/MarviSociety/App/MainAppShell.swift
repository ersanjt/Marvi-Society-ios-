import SwiftUI

struct MainAppShell: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView {
            switch appState.selectedRole {
            case .creator:
                DiscoverView()
                    .tabItem {
                        Label("Discover", systemImage: "sparkles")
                    }

                MapDiscoverView()
                    .tabItem {
                        Label("Nearby", systemImage: "map")
                    }

                BookingsView()
                    .tabItem {
                        Label("Bookings", systemImage: "calendar.badge.checkmark")
                    }

                InboxView()
                    .tabItem {
                        Label("Inbox", systemImage: "bell")
                    }

                ProfileView()
                    .tabItem {
                        Label("Profile", systemImage: "person.crop.circle")
                    }

            case .venue:
                VenueStudioView()
                    .tabItem {
                        Label("Studio", systemImage: "building.2.crop.circle")
                    }

                InboxView()
                    .tabItem {
                        Label("Inbox", systemImage: "bell")
                    }

                ProfileView()
                    .tabItem {
                        Label("Account", systemImage: "person.crop.circle")
                    }

            case .admin:
                AdminDashboardView()
                    .tabItem {
                        Label("Admin", systemImage: "checkmark.shield")
                    }

                InboxView()
                    .tabItem {
                        Label("Inbox", systemImage: "bell")
                    }

                ProfileView()
                    .tabItem {
                        Label("Account", systemImage: "person.crop.circle")
                    }
            }
        }
    }
}
