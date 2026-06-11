import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if !APIConfig.isSupabaseConfigured {
                ConfigurationRequiredView()
            } else if appState.needsReauthentication {
                ReauthView()
            } else if appState.isBootstrapping && appState.hasCompletedOnboarding {
                BootstrapSplashView()
            } else if appState.hasCompletedOnboarding {
                MainAppShell()
            } else {
                OnboardingView()
            }
        }
        .tint(MarviColor.rose)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
