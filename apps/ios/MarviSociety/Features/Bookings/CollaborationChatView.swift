import SwiftUI

struct CollaborationChatView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedConversation: ChatConversation?
    @State private var draft = ""

    var body: some View {
        NavigationStack {
            MarviScreen {
                if appState.conversations.isEmpty {
                    EmptyStateView(
                        title: appState.t(.noMessagesYet),
                        subtitle: appState.t(.noMessagesYetSub),
                        icon: "bubble.left.and.bubble.right",
                        actionTitle: appState.t(.refresh),
                        action: { Task { await appState.loadConversations() } }
                    )
                    .padding(16)
                } else {
                    List(appState.conversations) { conversation in
                        Button {
                            selectedConversation = conversation
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(conversation.venueName.isEmpty ? conversation.offerTitle : conversation.venueName)
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(MarviColor.ink)
                                Text(conversation.preview)
                                    .font(.caption)
                                    .foregroundStyle(MarviColor.muted)
                                    .lineLimit(2)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(appState.t(.messagesTitle))
            .task { await appState.loadConversations() }
            .refreshable { await appState.loadConversations() }
            .sheet(item: $selectedConversation) { conversation in
                ChatThreadView(conversation: conversation)
                    .environmentObject(appState)
            }
        }
    }
}

private struct ChatThreadView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    let conversation: ChatConversation

    @State private var messages: [ChatMessage] = []
    @State private var draft = ""
    @State private var isSending = false
    @State private var myUserID: UUID?

    var body: some View {
        NavigationStack {
            MarviScreen {
                VStack(spacing: 0) {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            ForEach(messages) { message in
                                ChatBubble(
                                    message: message,
                                    isMine: message.senderUserID == myUserID
                                )
                            }
                        }
                        .padding(16)
                    }

                    HStack(spacing: 10) {
                        MarviTextField(placeholder: appState.t(.messagePlaceholder), text: $draft)
                        Button {
                            Task { await send() }
                        } label: {
                            Image(systemName: "paperplane.fill")
                                .foregroundStyle(MarviColor.rose)
                        }
                        .disabled(isSending || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(12)
                    .background(MarviColor.panel)
                }
            }
            .navigationTitle(conversation.venueName.isEmpty ? conversation.offerTitle : conversation.venueName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(appState.t(.close)) { dismiss() }
                }
            }
            .task {
                myUserID = await appState.resolvedUserID()
                await loadMessages()
            }
        }
    }

    @MainActor
    private func loadMessages() async {
        messages = await appState.fetchChatMessages(conversationID: conversation.id)
    }

    @MainActor
    private func send() async {
        isSending = true
        defer { isSending = false }
        let text = draft
        draft = ""
        guard await appState.sendChatMessage(conversationID: conversation.id, body: text) else { return }
        await loadMessages()
    }
}

private struct ChatBubble: View {
    let message: ChatMessage
    let isMine: Bool

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 40) }
            Text(message.body)
                .font(.subheadline)
                .foregroundStyle(isMine ? .white : MarviColor.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isMine ? AnyShapeStyle(MarviGradient.brand) : AnyShapeStyle(MarviColor.panel))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            if !isMine { Spacer(minLength: 40) }
        }
    }
}
