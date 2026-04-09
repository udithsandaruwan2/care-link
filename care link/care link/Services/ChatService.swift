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
        conversationListener = db.collection("conversations")
            .whereField(field, isEqualTo: userId)
            .order(by: "lastMessageAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, let snapshot else { return }
                self.conversations = snapshot.documents.compactMap { doc in
                    try? doc.data(as: ChatConversation.self)
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

        try await db.collection("conversations").document(conversationId).updateData([
            "lastMessage": text,
            "lastMessageAt": Timestamp(date: Date())
        ])
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

        try await db.collection("conversations").document(conversationId).updateData([
            "lastMessage": preview,
            "lastMessageAt": Timestamp(date: Date())
        ])
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
    }

    func unreadCount(for userId: String, role: CLUser.UserRole) -> Int {
        conversations.reduce(0) { total, conv in
            total + (role == .user ? conv.unreadCountUser : conv.unreadCountCaregiver)
        }
    }
}
