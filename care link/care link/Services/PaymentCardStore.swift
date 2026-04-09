import Foundation

@Observable
final class PaymentCardStore {
    private let defaults = UserDefaults.standard
    private let keyPrefix = "carelink.paymentCards."

    func loadCards(for userId: String) -> [PaymentCard] {
        guard let data = defaults.data(forKey: keyPrefix + userId),
              let cards = try? JSONDecoder().decode([PaymentCard].self, from: data) else {
            return defaultCards
        }
        return cards
    }

    func saveCards(_ cards: [PaymentCard], for userId: String) {
        guard let data = try? JSONEncoder().encode(cards) else { return }
        defaults.set(data, forKey: keyPrefix + userId)
    }

    private var defaultCards: [PaymentCard] {
        [
            PaymentCard(
                id: "card_demo_primary",
                cardholderName: "CareLink User",
                brand: "VISA",
                last4: "4290",
                expiryMonth: "12",
                expiryYear: "26",
                isPrimary: true,
                createdAt: Date()
            )
        ]
    }
}
