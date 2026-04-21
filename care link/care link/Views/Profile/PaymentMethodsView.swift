import SwiftUI
import FirebaseAuth

struct PaymentMethodsView: View {
    @Environment(AppState.self) private var appState
    @State private var store = PaymentCardStore()
    @State private var cards: [PaymentCard] = []
    @State private var showAddCard = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CLTheme.spacingMD) {
                titleBlock
                ForEach(cards) { card in
                    cardView(card)
                }
                historyBlock
                CLButton(title: "Add New Card", icon: "plus.circle") {
                    showAddCard = true
                }
                .padding(.top, CLTheme.spacingSM)
            }
            .padding(.horizontal, CLTheme.spacingMD)
            .padding(.bottom, 90)
        }
        .background(CLTheme.backgroundPrimary)
        .navigationTitle("Payment Methods")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddCard) {
            AddNewCardView { newCard in
                if newCard.isPrimary {
                    cards = cards.map {
                        var copy = $0
                        copy.isPrimary = false
                        return copy
                    }
                }
                cards.insert(newCard, at: 0)
                persist()
            }
            .environment(appState)
        }
        .onAppear {
            loadCards()
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: CLTheme.spacingSM) {
            Text("Demo wallet")
                .font(CLTheme.headlineFont)
                .foregroundStyle(CLTheme.primaryNavy)
            Text("Cards and balances stay on this device for development and demos. There is no live Stripe processing in this build.")
                .font(CLTheme.captionFont)
                .foregroundStyle(CLTheme.textSecondary)
            Text("Manage your saved payment methods below.")
                .font(CLTheme.bodyFont)
                .foregroundStyle(CLTheme.textSecondary)
        }
        .padding(CLTheme.spacingMD)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CLTheme.lightBlue.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: CLTheme.cornerRadiusMD, style: .continuous))
    }

    private func cardView(_ card: PaymentCard) -> some View {
        VStack(alignment: .leading, spacing: CLTheme.spacingMD) {
            HStack {
                Text(card.brand)
                    .font(CLTheme.headlineFont)
                    .foregroundStyle(.white)
                Spacer()
                if card.isPrimary {
                    Text("Primary")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.2))
                        .clipShape(Capsule())
                }
            }

            Text(card.maskedNumber)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("EXPIRES")
                        .font(CLTheme.smallFont)
                        .foregroundStyle(.white.opacity(0.85))
                    Text("\(card.expiryMonth)/\(card.expiryYear)")
                        .font(CLTheme.calloutFont.weight(.semibold))
                        .foregroundStyle(.white)
                }
                Spacer()
                Button {
                    setPrimary(card)
                } label: {
                    Text(card.isPrimary ? "Primary" : "Set Primary")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.18))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(CLTheme.spacingMD)
        .background(CLTheme.gradientBlue)
        .clipShape(CLTheme.continuousRect(cornerRadius: CLTheme.cornerRadiusLG))
        .shadow(color: CLTheme.primaryNavy.opacity(0.25), radius: 10, y: 5)
    }

    private var historyBlock: some View {
        CLCard {
            VStack(alignment: .leading, spacing: CLTheme.spacingSM) {
                Text("Payment History")
                    .font(CLTheme.headlineFont)
                    .foregroundStyle(CLTheme.textPrimary)
                Text("Review your past consultations and billing statements.")
                    .font(CLTheme.calloutFont)
                    .foregroundStyle(CLTheme.textSecondary)
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundStyle(CLTheme.tealAccent)
                    Text("View all transactions")
                        .font(CLTheme.calloutFont.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(CLTheme.textTertiary)
                }
                .padding(CLTheme.spacingMD)
                .background(CLTheme.backgroundSecondary)
                .clipShape(CLTheme.continuousRect(cornerRadius: CLTheme.cornerRadiusMD))
            }
        }
    }

    private func setPrimary(_ card: PaymentCard) {
        cards = cards.map {
            var copy = $0
            copy.isPrimary = copy.id == card.id
            return copy
        }
        persist()
    }

    private func loadCards() {
        let userId = appState.authService.currentUser?.uid ?? ""
        cards = store.loadCards(for: userId)
    }

    private func persist() {
        let userId = appState.authService.currentUser?.uid ?? ""
        store.saveCards(cards, for: userId)
    }
}

#Preview {
    NavigationStack {
        PaymentMethodsView()
            .environment(AppState())
    }
}
