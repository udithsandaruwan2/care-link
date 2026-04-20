import SwiftUI
import FirebaseAuth


struct ChatListView: View {
    @Environment(AppState.self) private var appState
    @Binding var suppressMainTabBar: Bool
    @State private var selectedConversation: ChatConversation?
    @State private var showChat = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Text("Messages")
                        .font(CLTheme.titleFont)
                        .foregroundStyle(CLTheme.textPrimary)
                    Spacer()
                }
                .padding(.horizontal, CLTheme.spacingMD)
                .padding(.vertical, CLTheme.spacingSM)

                if appState.chatService.conversations.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(appState.chatService.conversations) { conversation in
                                conversationRow(conversation)
                                    .onTapGesture {
                                        selectedConversation = conversation
                                        showChat = true
                                    }
                            }
                        }
                        .padding(.bottom, 100)
                    }
                }
            }
            .background(CLTheme.backgroundPrimary)
            .navigationDestination(isPresented: $showChat) {
                if let conversation = selectedConversation {
                    ChatDetailView(conversation: conversation)
                        .environment(appState)
                }
            }
            .onAppear {
                syncMainTabBarVisibility()
                let userId = appState.authService.currentUser?.uid ?? ""
                if !userId.isEmpty, !appState.chatService.isListeningConversations {
                    appState.chatService.listenToConversations(
                        userId: userId,
                        role: appState.currentUserRole
                    )
                }
            }
            .onChange(of: showChat) { _, _ in syncMainTabBarVisibility() }
        }
    }

    private func syncMainTabBarVisibility() {
        suppressMainTabBar = showChat
    }

    private func conversationRow(_ conversation: ChatConversation) -> some View {
        let isUser = appState.currentUserRole == .user
        let displayName = isUser ? conversation.caregiverName : conversation.userName
        let subtitle = isUser ? conversation.caregiverSpecialty : "Patient"
        let unread = isUser ? conversation.unreadCountUser : conversation.unreadCountCaregiver

        return HStack(spacing: CLTheme.spacingMD) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(CLTheme.primaryNavy.opacity(0.12))
                    .frame(width: 52, height: 52)
                    .overlay {
                        Text(String(displayName.prefix(2)).uppercased())
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(CLTheme.primaryNavy)
                    }

                if unread > 0 {
                    Circle()
                        .fill(CLTheme.accentBlue)
                        .frame(width: 14, height: 14)
                        .overlay {
                            Text("\(unread)")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .offset(x: 2, y: 2)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(displayName)
                        .font(unread > 0 ? CLTheme.headlineFont : CLTheme.bodyFont)
                        .foregroundStyle(CLTheme.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    Text(conversation.lastMessageAt, style: .relative)
                        .font(CLTheme.captionFont)
                        .foregroundStyle(CLTheme.textTertiary)
                }

                Text(conversation.lastMessage.isEmpty ? "No messages yet" : conversation.lastMessage)
                    .font(CLTheme.captionFont)
                    .foregroundStyle(CLTheme.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, CLTheme.spacingMD)
        .padding(.vertical, CLTheme.spacingSM)
        .background(unread > 0 ? CLTheme.lightBlue.opacity(0.3) : CLTheme.cardBackground)
    }

    private var emptyState: some View {
        VStack(spacing: CLTheme.spacingMD) {
            Spacer()
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundStyle(CLTheme.textTertiary)
            Text("No conversations yet")
                .font(CLTheme.headlineFont)
                .foregroundStyle(CLTheme.textSecondary)
            Text("Once you connect with a caregiver, you can start chatting here.")
                .font(CLTheme.bodyFont)
                .foregroundStyle(CLTheme.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, CLTheme.spacingXL)
            Spacer()
        }
    }
}

#Preview {
    ChatListView(suppressMainTabBar: .constant(false))
        .environment(AppState())
}
