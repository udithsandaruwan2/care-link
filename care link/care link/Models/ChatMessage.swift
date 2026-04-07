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
}
