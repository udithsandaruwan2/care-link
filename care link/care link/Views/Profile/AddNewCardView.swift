import SwiftUI

struct AddNewCardView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var cardholderName = ""
    @State private var cardNumber = ""
    @State private var expiry = ""
    @State private var cvv = ""
    @State private var saveAsPrimary = true

    let onSave: (PaymentCard) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: CLTheme.spacingLG) {
                    previewCard
                    formCard
                    CLButton(title: "Save Card", icon: "creditcard.fill") {
                        saveCard()
                    }
                    .disabled(!canSave)
                }
                .padding(CLTheme.spacingMD)
            }
            .background(CLTheme.backgroundPrimary)
            .navigationTitle("Add New Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: CLTheme.spacingMD) {
            HStack {
                Text("Secure")
                    .font(CLTheme.calloutFont.weight(.semibold))
                    .foregroundStyle(CLTheme.tealAccent)
                Spacer()
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(CLTheme.tealAccent)
            }
            Spacer(minLength: CLTheme.spacingMD)
            Text(masked(cardNumber))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            HStack {
                Text(cardholderName.isEmpty ? "Cardholder Name" : cardholderName.uppercased())
                Spacer()
                Text(expiry.isEmpty ? "MM/YY" : expiry)
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white.opacity(0.9))
        }
        .padding(CLTheme.spacingMD)
        .frame(height: 190)
        .background(CLTheme.gradientBlue)
        .clipShape(CLTheme.continuousRect(cornerRadius: CLTheme.cornerRadiusXL))
    }

    private var formCard: some View {
        CLCard {
            VStack(spacing: CLTheme.spacingMD) {
                CLTextField(placeholder: "Cardholder Name", text: $cardholderName, icon: "person")
                CLTextField(placeholder: "Card Number", text: $cardNumber, icon: "creditcard")
                    .onChange(of: cardNumber) { _, newValue in
                        cardNumber = String(newValue.filter(\.isNumber).prefix(16))
                    }
                HStack(spacing: CLTheme.spacingMD) {
                    CLTextField(placeholder: "MM/YY", text: $expiry, icon: "calendar")
                    CLTextField(placeholder: "CVV", text: $cvv, icon: "lock")
                        .onChange(of: cvv) { _, newValue in
                            cvv = String(newValue.filter(\.isNumber).prefix(4))
                        }
                }
                Toggle("Set as primary card", isOn: $saveAsPrimary)
                    .tint(CLTheme.tealAccent)
                    .font(CLTheme.calloutFont)
            }
        }
    }

    private var canSave: Bool {
        !cardholderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && cardNumber.count >= 12
            && !expiry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && cvv.count >= 3
    }

    private func masked(_ raw: String) -> String {
        let digits = raw.filter(\.isNumber)
        guard !digits.isEmpty else { return "•••• •••• •••• ••••" }
        let chunks = stride(from: 0, to: digits.count, by: 4).map { start in
            let end = min(start + 4, digits.count)
            let s = digits.index(digits.startIndex, offsetBy: start)
            let e = digits.index(digits.startIndex, offsetBy: end)
            return String(digits[s..<e])
        }
        return chunks.joined(separator: " ")
    }

    private func saveCard() {
        let digits = cardNumber.filter(\.isNumber)
        let last4 = String(digits.suffix(4))
        let parts = expiry.split(separator: "/").map(String.init)
        let month = parts.first ?? "01"
        let year = parts.count > 1 ? parts[1] : "30"
        let card = PaymentCard(
            id: "card_\(UUID().uuidString.prefix(10).lowercased())",
            cardholderName: cardholderName.trimmingCharacters(in: .whitespacesAndNewlines),
            brand: detectBrand(from: digits),
            last4: last4,
            expiryMonth: month,
            expiryYear: year,
            isPrimary: saveAsPrimary,
            createdAt: Date()
        )
        onSave(card)
        dismiss()
    }

    private func detectBrand(from digits: String) -> String {
        if digits.hasPrefix("4") { return "VISA" }
        if digits.hasPrefix("5") { return "MASTERCARD" }
        if digits.hasPrefix("3") { return "AMEX" }
        return "CARD"
    }
}

#Preview {
    AddNewCardView { _ in }
}
