import Foundation

struct PaymentCard: Identifiable, Codable, Sendable {
    let id: String
    var cardholderName: String
    var brand: String
    var last4: String
    var expiryMonth: String
    var expiryYear: String
    var isPrimary: Bool
    var createdAt: Date

    var maskedNumber: String {
        "•••• •••• •••• \(last4)"
    }
}
