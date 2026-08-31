import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if !APIConfig.isSupabaseConfigured {
                ConfigurationRequiredView()
            } else if !appState.hasCompletedOnboarding {
                OnboardingView()
            } else if appState.needsReauthentication {
                ReauthView()
            } else if appState.needsSocialHandlesEntry {
                SocialProfileSetupView()
            } else if appState.needsAdminApproval {
                ApprovalPendingView()
            } else if appState.isBootstrapping {
                BootstrapSplashView()
            } else {
                MainAppShell()
            }
        }
        .tint(MarviColor.rose)
        .preferredColorScheme(.dark)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                appState.handleAppBecameActive()
            }
        }
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AppState())
    }
}
#endif
