import Foundation

struct Booking: Identifiable, Codable, Sendable {
    let id: String
    var userId: String
    var caregiverId: String
    var caregiverName: String
    var caregiverSpecialty: String
    var caregiverImageURL: String
    var caregiverRating: Double
    var date: Date
    var startTime: Date
    var endTime: Date
    var duration: Double
    var totalCost: Double
    var status: BookingStatus
    var location: String
    var address: String
    var paymentMethod: PaymentMethod
    var createdAt: Date

    enum BookingStatus: String, Codable, Sendable, CaseIterable {
        case pending = "Pending"
        case confirmed = "Confirmed"
        case inProgress = "In Progress"
        case completed = "Completed"
        case cancelled = "Cancelled"

        var color: String {
            switch self {
            case .pending: return "F59E0B"
            case .confirmed: return "0066CC"
            case .inProgress: return "0D9488"
            case .completed: return "16A34A"
            case .cancelled: return "DC2626"
            }
        }
    }

    enum PaymentMethod: String, Codable, Sendable, CaseIterable {
        case card = "Card"
        case cash = "Cash"

        var iconName: String {
            switch self {
            case .card: return "creditcard.fill"
            case .cash: return "banknote.fill"
            }
        }

        var displayName: String { rawValue }

        var colorHex: String {
            switch self {
            case .card: return "0066CC"
            case .cash: return "16A34A"
            }
        }
    }

    init(id: String, userId: String, caregiverId: String, caregiverName: String, caregiverSpecialty: String, caregiverImageURL: String, caregiverRating: Double, date: Date, startTime: Date, endTime: Date, duration: Double, totalCost: Double, status: BookingStatus, location: String, address: String, paymentMethod: PaymentMethod, createdAt: Date) {
        self.id = id
        self.userId = userId
        self.caregiverId = caregiverId
        self.caregiverName = caregiverName
        self.caregiverSpecialty = caregiverSpecialty
        self.caregiverImageURL = caregiverImageURL
        self.caregiverRating = caregiverRating
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.duration = duration
        self.totalCost = totalCost
        self.status = status
        self.location = location
        self.address = address
        self.paymentMethod = paymentMethod
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        caregiverId = try container.decode(String.self, forKey: .caregiverId)
        caregiverName = try container.decode(String.self, forKey: .caregiverName)
        caregiverSpecialty = try container.decode(String.self, forKey: .caregiverSpecialty)
        caregiverImageURL = try container.decodeIfPresent(String.self, forKey: .caregiverImageURL) ?? ""
        caregiverRating = try container.decodeIfPresent(Double.self, forKey: .caregiverRating) ?? 0
        date = try container.decode(Date.self, forKey: .date)
        startTime = try container.decode(Date.self, forKey: .startTime)
        endTime = try container.decode(Date.self, forKey: .endTime)
        duration = try container.decode(Double.self, forKey: .duration)
        totalCost = try container.decode(Double.self, forKey: .totalCost)
        status = try container.decode(BookingStatus.self, forKey: .status)
        location = try container.decodeIfPresent(String.self, forKey: .location) ?? ""
        address = try container.decodeIfPresent(String.self, forKey: .address) ?? ""
        paymentMethod = try container.decodeIfPresent(PaymentMethod.self, forKey: .paymentMethod) ?? .cash
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
}
