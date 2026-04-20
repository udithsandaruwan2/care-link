import Foundation
import FirebaseFirestore

@Observable
final class ChatService {
    private var db: Firestore { Firestore.firestore() }

    var conversations: [ChatConversation] = []
    var currentMessages: [ChatMessage] = []
    var isListeningConversations = false
    var isListeningMessages = false

    private var conversationListener: ListenerRegistration?
    private var messageListener: ListenerRegistration?

    deinit {
        stopAllListeners()
    }

    // MARK: - Conversations

    func listenToConversations(userId: String, role: CLUser.UserRole) {
        stopConversationListener()
        isListeningConversations = true

        let field = role == .user ? "userId" : "caregiverId"
        let baseQuery = db.collection("conversations").whereField(field, isEqualTo: userId)
        conversationListener = baseQuery
            .order(by: "lastMessageAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let snapshot {
                    self.conversations = snapshot.documents.compactMap { doc in
                        try? doc.data(as: ChatConversation.self)
                    }
                    return
                }
                // If Firestore cannot serve the ordered query (e.g. missing index), fallback to base query
                // and sort locally so chat keeps working in real-time.
                if error != nil {
                    self.conversationListener?.remove()
                    self.conversationListener = baseQuery.addSnapshotListener { [weak self] fallbackSnapshot, _ in
                        guard let self, let fallbackSnapshot else { return }
                        self.conversations = fallbackSnapshot.documents.compactMap { doc in
                            try? doc.data(as: ChatConversation.self)
                        }
                        .sorted { $0.lastMessageAt > $1.lastMessageAt }
                    }
                }
            }
    }

    func stopConversationListener() {
        conversationListener?.remove()
        conversationListener = nil
        isListeningConversations = false
    }

    // MARK: - Messages

    func listenToMessages(conversationId: String) {
        stopMessageListener()
        isListeningMessages = true

        messageListener = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .order(by: "sentAt", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, let snapshot else { return }
                self.currentMessages = snapshot.documents.compactMap { doc in
                    try? doc.data(as: ChatMessage.self)
                }
            }
    }

    func stopMessageListener() {
        messageListener?.remove()
        messageListener = nil
        isListeningMessages = false
    }

    func stopAllListeners() {
        stopConversationListener()
        stopMessageListener()
    }

    // MARK: - Send Message

    func sendMessage(conversationId: String, senderId: String, senderName: String, text: String) async throws {
        let messageId = UUID().uuidString
        let message = ChatMessage(
            id: messageId,
            conversationId: conversationId,
            senderId: senderId,
            senderName: senderName,
            text: text,
            sentAt: Date(),
            isRead: false,
            kind: .text,
            bookingId: nil
        )

        let data = try Firestore.Encoder().encode(message)
        try await db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .document(messageId)
            .setData(data)

        try await updateConversationAfterSend(
            conversationId: conversationId,
            senderId: senderId,
            lastMessage: text
        )
    }

    /// Sends a structured booking request bubble (caregiver can accept/decline from chat).
    func sendBookingRequestMessage(
        conversationId: String,
        senderId: String,
        senderName: String,
        booking: Booking
    ) async throws {
        let messageId = UUID().uuidString
        let preview = "📅 Booking: \(booking.date.formatted(date: .abbreviated, time: .omitted)) · $\(String(format: "%.0f", booking.totalCost))"
        let message = ChatMessage(
            id: messageId,
            conversationId: conversationId,
            senderId: senderId,
            senderName: senderName,
            text: preview,
            sentAt: Date(),
            isRead: false,
            kind: .bookingRequest,
            bookingId: booking.id
        )

        let data = try Firestore.Encoder().encode(message)
        try await db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .document(messageId)
            .setData(data)

        try await updateConversationAfterSend(
            conversationId: conversationId,
            senderId: senderId,
            lastMessage: preview
        )
    }

    // MARK: - Create Conversation

    func getOrCreateConversation(
        userId: String,
        userName: String,
        caregiverId: String,
        caregiverName: String,
        caregiverSpecialty: String
    ) async throws -> ChatConversation {
        let snapshot = try await db.collection("conversations")
            .whereField("userId", isEqualTo: userId)
            .whereField("caregiverId", isEqualTo: caregiverId)
            .limit(to: 1)
            .getDocuments()

        if let existing = snapshot.documents.first,
           let conversation = try? existing.data(as: ChatConversation.self) {
            return conversation
        }

        let conversationId = UUID().uuidString
        let conversation = ChatConversation(
            id: conversationId,
            userId: userId,
            userName: userName,
            caregiverId: caregiverId,
            caregiverName: caregiverName,
            caregiverSpecialty: caregiverSpecialty,
            lastMessage: "",
            lastMessageAt: Date(),
            unreadCountUser: 0,
            unreadCountCaregiver: 0
        )

        let data = try Firestore.Encoder().encode(conversation)
        try await db.collection("conversations").document(conversationId).setData(data)
        return conversation
    }

    // MARK: - Mark as Read

    func markMessagesAsRead(conversationId: String, readerId: String) async {
        let snapshot = try? await db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .whereField("isRead", isEqualTo: false)
            .getDocuments()

        guard let documents = snapshot?.documents else { return }
        for doc in documents {
            let senderId = doc.data()["senderId"] as? String ?? ""
            if senderId != readerId {
                try? await doc.reference.updateData(["isRead": true])
            }
        }
        if let conversation = try? await fetchConversation(conversationId: conversationId) {
            let unreadField = readerId == conversation.userId ? "unreadCountUser" : "unreadCountCaregiver"
            try? await db.collection("conversations").document(conversationId).updateData([unreadField: 0])
        }
    }

    func unreadCount(for userId: String, role: CLUser.UserRole) -> Int {
        conversations.reduce(0) { total, conv in
            total + (role == .user ? conv.unreadCountUser : conv.unreadCountCaregiver)
        }
    }

    // MARK: - Helpers

    private func fetchConversation(conversationId: String) async throws -> ChatConversation {
        let document = try await db.collection("conversations").document(conversationId).getDocument()
        guard let conversation = try? document.data(as: ChatConversation.self) else {
            throw NSError(domain: "ChatService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Conversation not found"])
        }
        return conversation
    }

    private func updateConversationAfterSend(
        conversationId: String,
        senderId: String,
        lastMessage: String
    ) async throws {
        let conversation = try await fetchConversation(conversationId: conversationId)
        let unreadField = senderId == conversation.userId ? "unreadCountCaregiver" : "unreadCountUser"
        try await db.collection("conversations").document(conversationId).updateData([
            "lastMessage": lastMessage,
            "lastMessageAt": Timestamp(date: Date()),
            unreadField: FieldValue.increment(Int64(1))
        ])
    }
}
