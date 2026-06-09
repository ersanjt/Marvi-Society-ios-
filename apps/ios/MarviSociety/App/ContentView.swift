import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if appState.hasCompletedOnboarding {
                MainAppShell()
            } else {
                OnboardingView()
            }
        }
        .tint(MarviColor.emerald)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
