import Foundation

struct ChatConversation: Identifiable, Codable, Sendable {
    let id: String
    var userId: String
    var userName: String
    var caregiverId: String
    var caregiverName: String
    var caregiverSpecialty: String
    var lastMessage: String
    var lastMessageAt: Date
    var unreadCountUser: Int
    var unreadCountCaregiver: Int
}

struct ChatMessage: Identifiable, Codable, Sendable {
    let id: String
    var conversationId: String
    var senderId: String
    var senderName: String
    var text: String
    var sentAt: Date
    var isRead: Bool
    /// Plain text vs structured booking request (shows accept/reject for caregiver).
    var kind: MessageKind
    var bookingId: String?

    enum MessageKind: String, Codable, Sendable {
        case text
        case bookingRequest
    }

    init(
        id: String,
        conversationId: String,
        senderId: String,
        senderName: String,
        text: String,
        sentAt: Date,
        isRead: Bool,
        kind: MessageKind = .text,
        bookingId: String? = nil
    ) {
        self.id = id
        self.conversationId = conversationId
        self.senderId = senderId
        self.senderName = senderName
        self.text = text
        self.sentAt = sentAt
        self.isRead = isRead
        self.kind = kind
        self.bookingId = bookingId
    }

    enum CodingKeys: String, CodingKey {
        case id, conversationId, senderId, senderName, text, sentAt, isRead, kind, bookingId
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        conversationId = try c.decode(String.self, forKey: .conversationId)
        senderId = try c.decode(String.self, forKey: .senderId)
        senderName = try c.decode(String.self, forKey: .senderName)
        text = try c.decode(String.self, forKey: .text)
        sentAt = try c.decode(Date.self, forKey: .sentAt)
        isRead = try c.decodeIfPresent(Bool.self, forKey: .isRead) ?? false
        kind = try c.decodeIfPresent(MessageKind.self, forKey: .kind) ?? .text
        bookingId = try c.decodeIfPresent(String.self, forKey: .bookingId)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(conversationId, forKey: .conversationId)
        try c.encode(senderId, forKey: .senderId)
        try c.encode(senderName, forKey: .senderName)
        try c.encode(text, forKey: .text)
        try c.encode(sentAt, forKey: .sentAt)
        try c.encode(isRead, forKey: .isRead)
        try c.encode(kind, forKey: .kind)
        try c.encodeIfPresent(bookingId, forKey: .bookingId)
    }
}
