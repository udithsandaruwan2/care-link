import Foundation

struct CLNotification: Identifiable, Codable, Sendable {
    let id: String
    var userId: String
    var senderUserId: String?
    var title: String
    var message: String
    var type: NotificationType
    var isRead: Bool
    var createdAt: Date
    var bookingId: String?
    var conversationId: String?

    enum NotificationType: String, Codable, Sendable {
        case bookingConfirmed = "booking_confirmed"
        case bookingRequest = "booking_request"
        case bookingReminder = "booking_reminder"
        case bookingCancelled = "booking_cancelled"
        case statusUpdate = "status_update"
        case connectionRequest = "connection_request"
        case connectionApproved = "connection_approved"
        case newMessage = "new_message"
        case general = "general"

        var iconName: String {
            switch self {
            case .bookingConfirmed: return "checkmark.circle.fill"
            case .bookingRequest: return "calendar.badge.plus"
            case .bookingReminder: return "bell.fill"
            case .bookingCancelled: return "xmark.circle.fill"
            case .statusUpdate: return "arrow.triangle.2.circlepath"
            case .connectionRequest: return "person.badge.plus"
            case .connectionApproved: return "person.fill.checkmark"
            case .newMessage: return "message.fill"
            case .general: return "info.circle.fill"
            }
        }

        var colorHex: String {
            switch self {
            case .bookingConfirmed: return "16A34A"
            case .bookingRequest: return "0066CC"
            case .bookingReminder: return "F59E0B"
            case .bookingCancelled: return "DC2626"
            case .statusUpdate: return "0D9488"
            case .connectionRequest: return "7C3AED"
            case .connectionApproved: return "16A34A"
            case .newMessage: return "0066CC"
            case .general: return "64748B"
            }
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, userId, senderUserId, title, message, type, isRead, createdAt, bookingId, conversationId
    }

    init(
        id: String,
        userId: String,
        senderUserId: String? = nil,
        title: String,
        message: String,
        type: NotificationType,
        isRead: Bool,
        createdAt: Date,
        bookingId: String? = nil,
        conversationId: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.senderUserId = senderUserId
        self.title = title
        self.message = message
        self.type = type
        self.isRead = isRead
        self.createdAt = createdAt
        self.bookingId = bookingId
        self.conversationId = conversationId
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        userId = try c.decodeIfPresent(String.self, forKey: .userId) ?? ""
        senderUserId = try c.decodeIfPresent(String.self, forKey: .senderUserId)
        title = try c.decode(String.self, forKey: .title)
        message = try c.decode(String.self, forKey: .message)
        type = try c.decode(NotificationType.self, forKey: .type)
        isRead = try c.decodeIfPresent(Bool.self, forKey: .isRead) ?? false
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        bookingId = try c.decodeIfPresent(String.self, forKey: .bookingId)
        conversationId = try c.decodeIfPresent(String.self, forKey: .conversationId)
    }
}
