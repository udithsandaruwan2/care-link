import Foundation

struct CLNotification: Identifiable, Codable, Sendable {
    let id: String
    var title: String
    var message: String
    var type: NotificationType
    var isRead: Bool
    var createdAt: Date
    var bookingId: String?

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
}
