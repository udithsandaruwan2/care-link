import SwiftUI
import FirebaseAuth

struct ChatDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let conversation: ChatConversation

    @State private var messageText = ""
    @State private var scrollProxy: ScrollViewProxy?

    private var currentUserId: String {
        appState.authService.currentUser?.uid ?? ""
    }

    private var displayName: String {
        appState.currentUserRole == .user ? conversation.caregiverName : conversation.userName
    }

    private var displaySubtitle: String {
        appState.currentUserRole == .user ? conversation.caregiverSpecialty : "Patient"
    }

    var body: some View {
        VStack(spacing: 0) {
            chatHeader

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: CLTheme.spacingSM) {
                        ForEach(appState.chatService.currentMessages) { message in
                            messageBubble(message)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal, CLTheme.spacingMD)
                    .padding(.vertical, CLTheme.spacingSM)
                }
                .onAppear { scrollProxy = proxy }
                .onChange(of: appState.chatService.currentMessages.count) { _, _ in
                    scrollToBottom()
                }
            }

            inputBar
        }
        .background(CLTheme.backgroundPrimary)
        .navigationBarHidden(true)
        .onAppear {
            appState.chatService.listenToMessages(conversationId: conversation.id)
            Task {
                await appState.chatService.markMessagesAsRead(
                    conversationId: conversation.id,
                    readerId: currentUserId
                )
            }
        }
        .onDisappear {
            appState.chatService.stopMessageListener()
        }
    }

    // MARK: - Header

    private var chatHeader: some View {
        HStack(spacing: CLTheme.spacingMD) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(CLTheme.textPrimary)
            }

            Circle()
                .fill(CLTheme.primaryNavy.opacity(0.12))
                .frame(width: 40, height: 40)
                .overlay {
                    Text(String(displayName.prefix(2)).uppercased())
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(CLTheme.primaryNavy)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(CLTheme.headlineFont)
                    .foregroundStyle(CLTheme.textPrimary)
                Text(displaySubtitle)
                    .font(CLTheme.captionFont)
                    .foregroundStyle(CLTheme.textSecondary)
            }

            Spacer()

            Circle()
                .fill(CLTheme.successGreen)
                .frame(width: 8, height: 8)
            Text("Online")
                .font(CLTheme.captionFont)
                .foregroundStyle(CLTheme.successGreen)
        }
        .padding(.horizontal, CLTheme.spacingMD)
        .padding(.vertical, CLTheme.spacingSM)
        .background(CLTheme.cardBackground.shadow(color: CLTheme.shadowLight, radius: 2, y: 1))
    }

    // MARK: - Message Bubble

    private func messageBubble(_ message: ChatMessage) -> some View {
        let isMine = message.senderId == currentUserId

        return HStack {
            if isMine { Spacer(minLength: 60) }

            VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .font(CLTheme.bodyFont)
                    .foregroundStyle(isMine ? .white : CLTheme.textPrimary)
                    .padding(.horizontal, CLTheme.spacingMD)
                    .padding(.vertical, CLTheme.spacingSM)
                    .background(isMine ? CLTheme.primaryNavy : CLTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: CLTheme.shadowLight, radius: isMine ? 0 : 2)

                HStack(spacing: 4) {
                    Text(message.sentAt.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 10))
                        .foregroundStyle(CLTheme.textTertiary)
                    if isMine {
                        Image(systemName: message.isRead ? "checkmark.circle.fill" : "checkmark.circle")
                            .font(.system(size: 10))
                            .foregroundStyle(message.isRead ? CLTheme.accentBlue : CLTheme.textTertiary)
                    }
                }
            }

            if !isMine { Spacer(minLength: 60) }
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: CLTheme.spacingSM) {
            TextField("Type a message...", text: $messageText, axis: .vertical)
                .font(CLTheme.bodyFont)
                .lineLimit(1...4)
                .padding(.horizontal, CLTheme.spacingMD)
                .padding(.vertical, CLTheme.spacingSM)
                .background(CLTheme.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 22))

            Button {
                sendMessage()
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(messageText.trimmingCharacters(in: .whitespaces).isEmpty ? CLTheme.textTertiary : CLTheme.primaryNavy)
                    .clipShape(Circle())
            }
            .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, CLTheme.spacingMD)
        .padding(.vertical, CLTheme.spacingSM)
        .background(CLTheme.cardBackground.shadow(color: CLTheme.shadowMedium, radius: 8, y: -2))
    }

    // MARK: - Actions

    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        messageText = ""

        Task {
            try? await appState.chatService.sendMessage(
                conversationId: conversation.id,
                senderId: currentUserId,
                senderName: appState.authService.userProfile?.fullName ?? "User",
                text: text
            )
        }
    }

    private func scrollToBottom() {
        if let last = appState.chatService.currentMessages.last {
            withAnimation(.easeOut(duration: 0.2)) {
                scrollProxy?.scrollTo(last.id, anchor: .bottom)
            }
        }
    }
}
