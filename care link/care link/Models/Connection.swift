import Foundation

struct Connection: Identifiable, Codable, Sendable {
    let id: String
    var userId: String
    var userName: String
    var caregiverId: String
    var caregiverName: String
    var caregiverSpecialty: String
    var status: ConnectionStatus
    var createdAt: Date

    enum ConnectionStatus: String, Codable, Sendable, CaseIterable {
        case pending = "pending"
        case approved = "approved"
        case rejected = "rejected"

        var displayName: String {
            switch self {
            case .pending: return "Pending"
            case .approved: return "Connected"
            case .rejected: return "Rejected"
            }
        }

        var colorHex: String {
            switch self {
            case .pending: return "F59E0B"
            case .approved: return "16A34A"
            case .rejected: return "DC2626"
            }
        }

        var iconName: String {
            switch self {
            case .pending: return "clock.fill"
            case .approved: return "checkmark.circle.fill"
            case .rejected: return "xmark.circle.fill"
            }
        }
    }
}
