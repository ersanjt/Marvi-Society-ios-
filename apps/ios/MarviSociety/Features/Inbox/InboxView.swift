import SwiftUI

struct InboxView: View {
    @EnvironmentObject private var appState: AppState

    private var lang: AppLanguage { appState.preferredLanguage }

    var body: some View {
        NavigationStack {
            MarviScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        BrandLockup(subtitle: MarviL10n.t(.inboxTitle, language: lang))

                        SectionTitle(
                            title: MarviL10n.t(.inboxTitle, language: lang),
                            subtitle: lang == .turkish
                                ? "Onaylar, hatırlatmalar ve venue güncellemeleri."
                                : "Operational updates, confirmations, and reminders."
                        )

                        if appState.inboxMessages.isEmpty {
                            MarviCard {
                                EmptyStateView(
                                    title: appState.isSyncing ? "Loading…" : MarviL10n.t(.inboxEmpty, language: lang),
                                    subtitle: appState.isSyncing
                                        ? (lang == .turkish ? "Bildirimler yükleniyor." : "Fetching your latest notifications.")
                                        : (lang == .turkish
                                            ? "Onaylar ve hatırlatmalar burada görünür."
                                            : "Confirmations, reminders, and venue updates will appear here."),
                                    icon: "tray",
                                    actionTitle: appState.isSyncing ? nil : "Refresh",
                                    action: appState.isSyncing ? nil : { Task { await appState.refreshFromServer() } }
                                )
                            }
                        } else {
                            ForEach(appState.inboxMessages) { message in
                                Button {
                                    appState.openInboxMessage(message)
                                } label: {
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

                                                    if !message.isRead {
                                                        Circle()
                                                            .fill(MarviColor.rose)
                                                            .frame(width: 8, height: 8)
                                                    }

                                                    Spacer()

                                                    Text(message.dateLabel)
                                                        .font(.caption)
                                                        .foregroundStyle(MarviColor.muted)
                                                }

                                                Text(message.body)
                                                    .font(.subheadline)
                                                    .foregroundStyle(MarviColor.graphite)
                                                    .fixedSize(horizontal: false, vertical: true)

                                                if message.deepLink != nil {
                                                    Label(
                                                        lang == .turkish ? "Aç" : "Open",
                                                        systemImage: "arrow.right.circle.fill"
                                                    )
                                                    .font(.caption.weight(.bold))
                                                    .foregroundStyle(MarviColor.emerald)
                                                }
                                            }
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(16)
                }
                .refreshable {
                    await appState.refreshFromServer()
                }
            }
            .navigationTitle(MarviL10n.t(.inboxTitle, language: lang))
        }
    }
}
