import SwiftUI

struct WelcomeView: View {
    var onGetStarted: () -> Void
    var onSignIn: () -> Void

    @State private var animate = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: CLTheme.spacingMD) {
                ZStack {
                    Circle()
                        .fill(CLTheme.lightBlue)
                        .frame(width: 100, height: 100)
                        .scaleEffect(animate ? 1.0 : 0.8)

                    Image(systemName: "heart.text.clipboard.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(CLTheme.primaryNavy)
                }

                Text("CareLink")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(CLTheme.primaryNavy)

                Text("Your Digital Health Sanctuary")
                    .font(CLTheme.bodyFont)
                    .foregroundStyle(CLTheme.textSecondary)
            }
            .padding(.bottom, CLTheme.spacingXL)

            CLTheme.continuousRect(cornerRadius: CLTheme.cornerRadiusHero)
                .fill(
                    LinearGradient(
                        colors: [CLTheme.tealAccent.opacity(0.6), CLTheme.primaryNavy.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 200)
                .overlay(alignment: .bottomLeading) {
                    Text("Compassionate care,\ndelivered digitally.")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(CLTheme.spacingLG)
                }
                .padding(.horizontal, CLTheme.spacingLG)

            Spacer()

            VStack(spacing: CLTheme.spacingMD) {
                CLButton(title: "Get Started", icon: "arrow.right") {
                    onGetStarted()
                }

                CLButton(title: "Sign In", style: .outline) {
                    onSignIn()
                }
            }
            .padding(.horizontal, CLTheme.spacingLG)

            Text("TRUSTED BY 50,000+ CAREGIVERS")
                .font(CLTheme.smallFont)
                .foregroundStyle(CLTheme.textTertiary)
                .tracking(2)
                .padding(.top, CLTheme.spacingLG)
                .padding(.bottom, CLTheme.spacingXL)
        }
        .background(CLTheme.backgroundPrimary)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animate = true
            }
        }
    }
}

#Preview {
    WelcomeView(onGetStarted: {}, onSignIn: {})
}
