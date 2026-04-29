import Foundation

struct Booking: Identifiable, Codable, Sendable {
    let id: String
    var userId: String
    /// Display name of the patient (for caregiver-facing UI).
    var patientName: String
    /// If set, identifies family member receiving care; nil means account owner.
    var careRecipientId: String?
    var careRecipientRelation: String?
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
    /// Two-step cancel flow metadata.
    var cancellationRequestedByUid: String?
    var cancellationRequestedByRole: String?
    var cancellationRequestedAt: Date?

    enum BookingStatus: String, Codable, Sendable, CaseIterable {
        /// User submitted; caregiver must accept in chat or dashboard.
        case awaitingCaregiver = "Awaiting caregiver"
        case pending = "Pending"
        case confirmed = "Confirmed"
        case inProgress = "In Progress"
        case completed = "Completed"
        case cancelled = "Cancelled"

        var color: String {
            switch self {
            case .awaitingCaregiver, .pending: return "F59E0B"
            case .confirmed: return "0066CC"
            case .inProgress: return "0D9488"
            case .completed: return "16A34A"
            case .cancelled: return "DC2626"
            }
        }

        var needsCaregiverAction: Bool {
            self == .awaitingCaregiver || self == .pending
        }

        /// While in these states, patient should not create another booking request.
        var blocksNewBookingRequest: Bool {
            self == .awaitingCaregiver || self == .pending || self == .confirmed || self == .inProgress
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

    init(id: String, userId: String, patientName: String = "", careRecipientId: String? = nil, careRecipientRelation: String? = nil, caregiverId: String, caregiverName: String, caregiverSpecialty: String, caregiverImageURL: String, caregiverRating: Double, date: Date, startTime: Date, endTime: Date, duration: Double, totalCost: Double, status: BookingStatus, location: String, address: String, paymentMethod: PaymentMethod, createdAt: Date, cancellationRequestedByUid: String? = nil, cancellationRequestedByRole: String? = nil, cancellationRequestedAt: Date? = nil) {
        self.id = id
        self.userId = userId
        self.patientName = patientName
        self.careRecipientId = careRecipientId
        self.careRecipientRelation = careRecipientRelation
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
        self.cancellationRequestedByUid = cancellationRequestedByUid
        self.cancellationRequestedByRole = cancellationRequestedByRole
        self.cancellationRequestedAt = cancellationRequestedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        patientName = try container.decodeIfPresent(String.self, forKey: .patientName) ?? ""
        careRecipientId = try container.decodeIfPresent(String.self, forKey: .careRecipientId)
        careRecipientRelation = try container.decodeIfPresent(String.self, forKey: .careRecipientRelation)
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
        cancellationRequestedByUid = try container.decodeIfPresent(String.self, forKey: .cancellationRequestedByUid)
        cancellationRequestedByRole = try container.decodeIfPresent(String.self, forKey: .cancellationRequestedByRole)
        cancellationRequestedAt = try container.decodeIfPresent(Date.self, forKey: .cancellationRequestedAt)
    }
}
