import SwiftUI

struct InboxView: View {
    @EnvironmentObject private var appState: AppState

    private var roleSubtitle: String {
        switch appState.selectedRole {
        case .creator:
            return appState.t(.inboxSubCreator)
        case .venue:
            return appState.t(.inboxSubBusiness)
        case .admin:
            return appState.t(.inboxSubAdmin)
        }
    }

    private var sections: [(InboxSection, [InboxMessage])] {
        let ordered = InboxSection.ordered(for: appState.selectedRole)
        return ordered.compactMap { section in
            let items = appState.inboxMessages.filter { $0.section == section }
            guard !items.isEmpty else { return nil }
            return (section, items)
        }
    }

    var body: some View {
        NavigationStack {
            MarviScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        BrandLockup(subtitle: appState.t(.inboxTitle))

                        SectionTitle(
                            title: appState.t(.inboxTitle),
                            subtitle: roleSubtitle
                        )

                        if !appState.inboxMessages.isEmpty {
                            HStack {
                                Text(String(format: appState.t(.inboxUnreadCount), appState.unreadInboxCount))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(MarviColor.muted)
                                Spacer()
                                Button(appState.t(.inboxMarkAllRead)) {
                                    appState.markAllInboxRead()
                                }
                                .font(.caption.weight(.bold))
                                .foregroundStyle(MarviColor.rose)
                                .buttonStyle(.plain)
                            }
                        }

                        if appState.inboxMessages.isEmpty {
                            EmptyStateView(
                                title: appState.isSyncing ? appState.t(.loading) : appState.t(.inboxEmpty),
                                subtitle: appState.isSyncing
                                    ? appState.t(.inboxLoading)
                                    : roleEmptySubtitle,
                                icon: "bell.slash"
                            )
                            .padding(.top, 24)
                        } else {
                            LazyVStack(alignment: .leading, spacing: 18) {
                                ForEach(sections, id: \.0.id) { section, messages in
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text(section.title(for: appState.selectedRole, language: appState.preferredLanguage))
                                            .font(.caption.weight(.bold))
                                            .textCase(.uppercase)
                                            .foregroundStyle(MarviColor.muted)

                                        ForEach(messages) { message in
                                            InboxMessageRow(
                                                message: message,
                                                language: appState.preferredLanguage,
                                                openLabel: appState.t(.openAction)
                                            ) {
                                                appState.openInboxMessage(message)
                                            }
                                            .transition(.asymmetric(
                                                insertion: .opacity,
                                                removal: .move(edge: .trailing).combined(with: .opacity)
                                            ))
                                        }
                                    }
                                }
                            }
                            .animation(.easeInOut(duration: 0.25), value: appState.inboxMessages.map(\.id))
                        }
                    }
                    .padding(16)
                }
                .refreshable {
                    await appState.refreshFromServer()
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

    private var roleEmptySubtitle: String {
        switch appState.selectedRole {
        case .creator: return appState.t(.inboxEmptyCreator)
        case .venue: return appState.t(.inboxEmptyBusiness)
        case .admin: return appState.t(.inboxEmptyAdmin)
        }
    }
}

private struct InboxMessageRow: View {
    let message: InboxMessage
    let language: AppLanguage
    let openLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: message.icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(message.tint.color)
                    .frame(width: 40, height: 40)
                    .background(message.tint.color.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(MarviL10n.localizeServerText(message.title, language: language))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(MarviColor.ink)
                        .multilineTextAlignment(.leading)
                    Text(MarviL10n.localizeServerText(message.body, language: language))
                        .font(.caption)
                        .foregroundStyle(MarviColor.muted)
                        .multilineTextAlignment(.leading)
                    Text(MarviL10n.localizeServerText(message.dateLabel, language: language))
                        .font(.caption2)
                        .foregroundStyle(MarviColor.muted)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 10) {
                    if !message.isRead {
                        Circle()
                            .fill(MarviColor.rose)
                            .frame(width: 8, height: 8)
                    }
                    Text(openLabel)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(MarviColor.emerald)
                }
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
        .accessibilityLabel(MarviL10n.localizeServerText(message.title, language: language))
        .accessibilityHint(openLabel)
    }
}
