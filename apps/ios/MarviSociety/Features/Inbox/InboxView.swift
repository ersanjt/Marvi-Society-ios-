import SwiftUI

struct InboxView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            MarviScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        BrandLockup(subtitle: "Notifications")

                        SectionTitle(title: "Inbox", subtitle: "Operational updates, confirmations, and reminders.")

                        ForEach(appState.inboxMessages) { message in
                            MarviCard {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: message.icon)
                                        .font(.headline.weight(.semibold))
                                        .foregroundStyle(message.tint.color)
                                        .frame(width: 38, height: 38)
                                        .background(message.tint.color.opacity(0.12))
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                                    VStack(alignment: .leading, spacing: 5) {
                                        HStack {
                                            Text(message.title)
                                                .font(.subheadline.weight(.bold))
                                                .foregroundStyle(MarviColor.ink)

                                            Spacer()

                                            Text(message.dateLabel)
                                                .font(.caption)
                                                .foregroundStyle(MarviColor.muted)
                                        }

                                        Text(message.body)
                                            .font(.subheadline)
                                            .foregroundStyle(MarviColor.graphite)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Inbox")
        }
    }
}
