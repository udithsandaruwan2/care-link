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
                guard let self else { return }
                guard let snapshot else { return }
                var decoded: [ChatMessage] = []
                decoded.reserveCapacity(snapshot.documents.count)
                for doc in snapshot.documents {
                    do {
                        decoded.append(try doc.data(as: ChatMessage.self))
                    } catch {
                        print("ChatService: skipped unreadable message \(doc.documentID): \(error)")
                    }
                }
                self.currentMessages = decoded
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
        let msgRef = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .document(messageId)
        let conversation = try await fetchConversation(conversationId: conversationId)
        let unreadField = senderId == conversation.userId ? "unreadCountCaregiver" : "unreadCountUser"
        let batch = db.batch()
        batch.setData(data, forDocument: msgRef)
        batch.updateData([
            "lastMessage": text,
            "lastMessageAt": Timestamp(date: Date()),
            unreadField: FieldValue.increment(Int64(1))
        ], forDocument: db.collection("conversations").document(conversationId))
        try await batch.commit()

        let receiverId = senderId == conversation.userId ? conversation.caregiverId : conversation.userId
        let notification = CLNotification(
            id: UUID().uuidString,
            userId: receiverId,
            senderUserId: senderId,
            title: "New message",
            message: "\(senderName): \(text)",
            type: .newMessage,
            isRead: false,
            createdAt: Date(),
            conversationId: conversationId
        )
        let nref = db.collection("users").document(receiverId).collection("notifications").document(notification.id)
        let ndata = try Firestore.Encoder().encode(notification)
        try? await nref.setData(ndata)
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
        let msgRef = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .document(messageId)
        let conversation = try await fetchConversation(conversationId: conversationId)
        let unreadField = senderId == conversation.userId ? "unreadCountCaregiver" : "unreadCountUser"
        let batch = db.batch()
        batch.setData(data, forDocument: msgRef)
        batch.updateData([
            "lastMessage": preview,
            "lastMessageAt": Timestamp(date: Date()),
            unreadField: FieldValue.increment(Int64(1))
        ], forDocument: db.collection("conversations").document(conversationId))
        try await batch.commit()

        let receiverId = senderId == conversation.userId ? conversation.caregiverId : conversation.userId
        let notification = CLNotification(
            id: UUID().uuidString,
            userId: receiverId,
            senderUserId: senderId,
            title: "Booking request in chat",
            message: "\(senderName) sent a booking request card.",
            type: .bookingRequest,
            isRead: false,
            createdAt: Date(),
            bookingId: booking.id,
            conversationId: conversationId
        )
        let nref = db.collection("users").document(receiverId).collection("notifications").document(notification.id)
        let ndata = try Firestore.Encoder().encode(notification)
        try? await nref.setData(ndata)
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
        let convRef = db.collection("conversations").document(conversationId)
        guard let snapshot = try? await convRef.collection("messages")
            .whereField("isRead", isEqualTo: false)
            .getDocuments()
        else { return }

        guard let conversation = try? await fetchConversation(conversationId: conversationId) else { return }
        let unreadField = readerId == conversation.userId ? "unreadCountUser" : "unreadCountCaregiver"

        let batch = db.batch()
        for doc in snapshot.documents {
            let senderId = doc.data()["senderId"] as? String ?? ""
            if senderId != readerId {
                batch.updateData(["isRead": true], forDocument: doc.reference)
            }
        }
        batch.updateData([unreadField: 0], forDocument: convRef)
        try? await batch.commit()
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

}
