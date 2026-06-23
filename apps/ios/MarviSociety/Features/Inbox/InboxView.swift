import SwiftUI

struct InboxView: View {
    @EnvironmentObject private var appState: AppState

    private var lang: AppLanguage { appState.preferredLanguage }

    var body: some View {
        NavigationStack {
            MarviScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        BrandLockup(subtitle: appState.t(.inboxTitle))

                        SectionTitle(
                            title: appState.t(.inboxTitle),
                            subtitle: appState.t(.inboxSub)
                        )

                        if appState.inboxMessages.isEmpty {
                            EmptyStateView(
                                title: appState.isSyncing ? appState.t(.loading) : appState.t(.inboxEmpty),
                                subtitle: appState.isSyncing
                                    ? appState.t(.inboxLoading)
                                    : appState.t(.inboxSub),
                                icon: "bell.slash"
                            )
                            .padding(.top, 24)
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(appState.inboxMessages) { message in
                                    InboxMessageRow(message: message, openLabel: appState.t(.openAction)) {
                                        appState.openInboxMessage(message)
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle(appState.t(.inboxTitle))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(appState.t(.refresh)) {
                        Task { await appState.refreshFromServer() }
                    }
                }
            }
        }
    }
}

private struct InboxMessageRow: View {
    let message: InboxMessage
    let openLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(message.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(MarviColor.ink)
                        .multilineTextAlignment(.leading)
                    Text(message.body)
                        .font(.caption)
                        .foregroundStyle(MarviColor.muted)
                        .multilineTextAlignment(.leading)
                    Text(message.dateLabel)
                        .font(.caption2)
                        .foregroundStyle(MarviColor.muted)
                }
                Spacer()
                if !message.isRead {
                    Circle()
                        .fill(MarviColor.rose)
                        .frame(width: 8, height: 8)
                }
                Text(openLabel)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MarviColor.emerald)
            }
            .padding(14)
            .background(MarviColor.panel)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(MarviColor.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
