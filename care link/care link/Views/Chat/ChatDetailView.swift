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

    private var isCaregiverInThread: Bool {
        currentUserId == conversation.caregiverId
    }

    var body: some View {
        VStack(spacing: 0) {
            chatHeader

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: CLTheme.spacingSM) {
                        ForEach(appState.chatService.currentMessages) { message in
                            messageRow(message)
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

    @ViewBuilder
    private func messageRow(_ message: ChatMessage) -> some View {
        switch message.kind {
        case .bookingRequest:
            bookingRequestRow(message)
        case .text:
            textBubble(message)
        }
    }

    // MARK: - Text (WhatsApp-style)

    private func textBubble(_ message: ChatMessage) -> some View {
        let isMine = message.senderId == currentUserId

        return HStack(alignment: .bottom, spacing: 6) {
            if isMine { Spacer(minLength: 48) }

            if !isMine {
                Circle()
                    .fill(CLTheme.primaryNavy.opacity(0.15))
                    .frame(width: 28, height: 28)
                    .overlay {
                        Text(String(message.senderName.prefix(1)).uppercased())
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(CLTheme.primaryNavy)
                    }
            }

            VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
                if !isMine {
                    Text(message.senderName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(CLTheme.textTertiary)
                        .padding(.horizontal, 4)
                }

                Text(message.text)
                    .font(CLTheme.bodyFont)
                    .foregroundStyle(isMine ? .white : CLTheme.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(isMine ? CLTheme.primaryNavy : CLTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: isMine ? .clear : CLTheme.shadowLight.opacity(0.85), radius: 4, y: 2)

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
                .padding(.horizontal, 4)
            }

            if !isMine { Spacer(minLength: 48) }
        }
    }

    // MARK: - Booking request card

    private func bookingRequestRow(_ message: ChatMessage) -> some View {
        let isMine = message.senderId == currentUserId

        return HStack {
            if isMine { Spacer(minLength: 32) }
            BookingRequestChatCard(
                message: message,
                conversation: conversation,
                showCaregiverActions: isCaregiverInThread && !isMine
            )
            .environment(appState)
            if !isMine { Spacer(minLength: 32) }
        }
    }

    // MARK: - Header

    private var chatHeader: some View {
        HStack(spacing: CLTheme.spacingMD) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(CLTheme.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(CLTheme.backgroundSecondary)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

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

    // MARK: - Input

    private var inputBar: some View {
        HStack(spacing: CLTheme.spacingSM) {
            TextField("Message", text: $messageText, axis: .vertical)
                .font(CLTheme.bodyFont)
                .lineLimit(1...5)
                .padding(.horizontal, CLTheme.spacingMD)
                .padding(.vertical, CLTheme.spacingSM)
                .background(CLTheme.backgroundSecondary)
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .stroke(CLTheme.divider.opacity(0.55), lineWidth: 1)
                }

            Button {
                sendMessage()
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(messageText.trimmingCharacters(in: .whitespaces).isEmpty ? CLTheme.textTertiary : CLTheme.primaryNavy)
                    .clipShape(Circle())
                    .shadow(color: messageText.trimmingCharacters(in: .whitespaces).isEmpty ? .clear : CLTheme.primaryNavy.opacity(0.25), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, CLTheme.spacingMD)
        .padding(.vertical, CLTheme.spacingSM)
        .background(CLTheme.cardBackground.shadow(color: CLTheme.shadowMedium, radius: 8, y: -2))
    }

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

// MARK: - Booking request inline card

private struct BookingRequestChatCard: View {
    @Environment(AppState.self) private var appState
    let message: ChatMessage
    let conversation: ChatConversation
    let showCaregiverActions: Bool

    @State private var booking: Booking?
    @State private var isLoading = true
    @State private var isWorking = false

    var body: some View {
        VStack(alignment: .leading, spacing: CLTheme.spacingMD) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .foregroundStyle(CLTheme.tealAccent)
                Text("Booking request")
                    .font(CLTheme.headlineFont)
                    .foregroundStyle(CLTheme.textPrimary)
                Spacer()
            }

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if let b = booking {
                VStack(alignment: .leading, spacing: 6) {
                    Text(b.patientName.isEmpty ? "Patient" : b.patientName)
                        .font(CLTheme.calloutFont)
                        .foregroundStyle(CLTheme.textSecondary)
                    Text("\(b.date.formatted(date: .abbreviated, time: .omitted)) · \(b.startTime.formatted(date: .omitted, time: .shortened)) – \(b.endTime.formatted(date: .omitted, time: .shortened))")
                        .font(CLTheme.bodyFont)
                        .foregroundStyle(CLTheme.textPrimary)
                    Text(String(format: "%.1f h · $%.2f · %@", b.duration, b.totalCost, b.paymentMethod.displayName))
                        .font(CLTheme.captionFont)
                        .foregroundStyle(CLTheme.textTertiary)
                }

                statusChip(for: b.status)

                if showCaregiverActions && b.status.needsCaregiverAction {
                    HStack(spacing: CLTheme.spacingSM) {
                        Button {
                            respond(accept: false)
                        } label: {
                            Text("Decline")
                                .font(CLTheme.calloutFont)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .foregroundStyle(CLTheme.errorRed)
                                .background(CLTheme.errorRed.opacity(0.12))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(isWorking)

                        Button {
                            respond(accept: true)
                        } label: {
                            Text("Accept")
                                .font(CLTheme.calloutFont)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .foregroundStyle(.white)
                                .background(CLTheme.successGreen)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(isWorking)
                    }
                }
            } else {
                Text("Could not load booking.")
                    .font(CLTheme.captionFont)
                    .foregroundStyle(CLTheme.textTertiary)
            }

            Text(message.sentAt.formatted(date: .omitted, time: .shortened))
                .font(.system(size: 10))
                .foregroundStyle(CLTheme.textTertiary)
        }
        .padding(CLTheme.spacingMD)
        .frame(maxWidth: 320, alignment: .leading)
        .background(CLTheme.backgroundSecondary)
        .clipShape(CLTheme.continuousRect(cornerRadius: CLTheme.cornerRadiusLG))
        .overlay {
            CLTheme.continuousRect(cornerRadius: CLTheme.cornerRadiusLG)
                .stroke(CLTheme.tealAccent.opacity(0.35), lineWidth: 1)
        }
        .task(id: message.bookingId) {
            await loadBooking()
        }
    }

    @ViewBuilder
    private func statusChip(for status: Booking.BookingStatus) -> some View {
        Text(status.rawValue)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color(hex: status.color))
            .clipShape(Capsule())
    }

    private func loadBooking() async {
        guard let bid = message.bookingId else {
            isLoading = false
            return
        }
        isLoading = true
        booking = try? await appState.firestoreService.fetchBooking(bookingId: bid)
        isLoading = false
    }

    private func respond(accept: Bool) {
        guard let bid = message.bookingId else { return }
        let caregiverUid = appState.authService.currentUser?.uid ?? ""
        isWorking = true
        Task {
            do {
                if accept {
                    _ = try await appState.firestoreService.applyBookingTransition(
                        bookingId: bid,
                        to: .confirmed,
                        actor: .caregiver,
                        callerUid: caregiverUid
                    )
                } else {
                    _ = try await appState.firestoreService.applyBookingTransition(
                        bookingId: bid,
                        to: .cancelled,
                        actor: .caregiver,
                        callerUid: caregiverUid
                    )
                }
                booking = try? await appState.firestoreService.fetchBooking(bookingId: bid)
                let note = accept ? "✅ Booking accepted." : "Booking declined."
                try? await appState.chatService.sendMessage(
                    conversationId: conversation.id,
                    senderId: appState.authService.currentUser?.uid ?? "",
                    senderName: appState.authService.userProfile?.fullName ?? "Caregiver",
                    text: note
                )
            }
            await MainActor.run { isWorking = false }
        }
    }
}
