import SwiftUI

struct ConfigurationRequiredView: View {
    var body: some View {
        MarviScreen {
            VStack(spacing: 24) {
                Spacer()
                BrandMark(size: 72)
                VStack(spacing: 10) {
                    Text(MarviL10n.t(.configurationRequired, language: .turkish))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(MarviColor.ink)
                    Text(MarviL10n.t(.configurationSub, language: .turkish))
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
