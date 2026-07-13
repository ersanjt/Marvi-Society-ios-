import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if !APIConfig.isSupabaseConfigured {
                ConfigurationRequiredView()
            } else if !appState.hasCompletedOnboarding {
                OnboardingView()
            } else if appState.needsReauthentication {
                ReauthView()
            } else if appState.needsInviteRedemption {
                InviteRequiredView()
            } else if appState.needsSocialHandlesEntry {
                SocialProfileSetupView()
            } else if appState.isBootstrapping {
                BootstrapSplashView()
            } else {
                MainAppShell()
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
