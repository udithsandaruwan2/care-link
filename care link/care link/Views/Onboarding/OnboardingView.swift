import SwiftUI

struct OnboardingView: View {
    var onComplete: () -> Void

    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "Care with a\nHuman Touch.",
            description: "Experience a healthcare platform that prioritizes empathy and connection above all else. Your journey to better health begins with personalized, compassionate support.",
            icon: "heart.fill",
            iconColor: "0D9488",
            badgeText: "Trusted by 10k+",
            badgeIcon: "heart.fill",
            gradient: [Color(hex: "E0F2FE"), Color(hex: "BAE6FD")]
        ),
        OnboardingPage(
            title: "Smart Matching,\nYour Way.",
            description: "Find the perfect care fit by setting custom filters for specialized experience, proximity, and verified patient ratings.",
            icon: "location.fill",
            iconColor: "0D9488",
            badgeText: "Top Match",
            badgeIcon: "star.fill",
            gradient: [Color(hex: "E8EAF0"), Color(hex: "D1D5DB")]
        ),
        OnboardingPage(
            title: "Security is Our\nPriority.",
            description: "Your health data is a private matter. We use hospital-grade encryption and biometric authentication to ensure your records stay yours alone.",
            icon: "shield.checkered",
            iconColor: "0066CC",
            badgeText: "HIPAA Compliant",
            badgeIcon: "lock.shield.fill",
            gradient: [Color(hex: "E0F7FA"), Color(hex: "B2EBF2")]
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: CLTheme.spacingSM) {
                    Image(systemName: "cross.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(CLTheme.primaryNavy)
                    Text("CareLink")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(CLTheme.primaryNavy)
                }
                Spacer()
                Button("Skip") {
                    onComplete()
                }
                .font(CLTheme.calloutFont)
                .foregroundStyle(CLTheme.textSecondary)
            }
            .padding(.horizontal, CLTheme.spacingMD)
            .padding(.top, CLTheme.spacingSM)

            TabView(selection: $currentPage) {
                ForEach(pages.indices, id: \.self) { index in
                    onboardingContent(pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack(spacing: CLTheme.spacingMD) {
                HStack(spacing: 8) {
                    ForEach(pages.indices, id: \.self) { index in
                        Capsule()
                            .fill(currentPage == index ? CLTheme.primaryNavy : CLTheme.divider)
                            .frame(width: currentPage == index ? 24 : 8, height: 8)
                            .animation(.spring(response: 0.3), value: currentPage)
                    }
                }

                CLButton(
                    title: currentPage == pages.count - 1 ? "Done" : "Next",
                    icon: "arrow.right"
                ) {
                    if currentPage < pages.count - 1 {
                        withAnimation { currentPage += 1 }
                    } else {
                        onComplete()
                    }
                }
                .padding(.horizontal, CLTheme.spacingLG)

                Text("By continuing, you agree to our ")
                    .font(CLTheme.captionFont)
                    .foregroundStyle(CLTheme.textTertiary)
                +
                Text("Terms of Service")
                    .font(CLTheme.captionFont)
                    .foregroundStyle(CLTheme.accentBlue)
                +
                Text(" and Privacy Policy.")
                    .font(CLTheme.captionFont)
                    .foregroundStyle(CLTheme.textTertiary)
            }
            .padding(.bottom, CLTheme.spacingXL)
        }
        .background(CLTheme.backgroundPrimary)
    }

    private func onboardingContent(_ page: OnboardingPage) -> some View {
        VStack(spacing: CLTheme.spacingLG) {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: CLTheme.cornerRadiusXL)
                    .fill(
                        LinearGradient(
                            colors: page.gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 280)

                VStack(spacing: CLTheme.spacingMD) {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.3))
                            .frame(width: 80, height: 80)
                        Image(systemName: page.icon)
                            .font(.system(size: 36))
                            .foregroundStyle(Color(hex: page.iconColor))
                    }

                    HStack(spacing: 6) {
                        Image(systemName: page.badgeIcon)
                            .font(.system(size: 12))
                        Text(page.badgeText)
                            .font(CLTheme.captionFont)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, CLTheme.spacingLG)

            VStack(spacing: CLTheme.spacingMD) {
                Text(page.title)
                    .font(CLTheme.largeTitleFont)
                    .foregroundStyle(CLTheme.textPrimary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(page.description)
                    .font(CLTheme.bodyFont)
                    .foregroundStyle(CLTheme.textSecondary)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, CLTheme.spacingLG)

            Spacer()
        }
    }
}

struct OnboardingPage {
    let title: String
    let description: String
    let icon: String
    let iconColor: String
    let badgeText: String
    let badgeIcon: String
    let gradient: [Color]
}

#Preview {
    OnboardingView(onComplete: {})
}
