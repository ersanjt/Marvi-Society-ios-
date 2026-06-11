import SwiftUI

struct ConfigurationRequiredView: View {
    var body: some View {
        MarviScreen {
            VStack(spacing: 24) {
                Spacer()
                BrandMark(size: 72)
                VStack(spacing: 10) {
                    Text("Configuration required")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(MarviColor.ink)
                    Text("Copy Config/Secrets.xcconfig.example to Secrets.xcconfig and add your Supabase project URL and anon key.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(MarviColor.muted)
                        .padding(.horizontal, 24)
                }
                Spacer()
            }
        }
    }
}
