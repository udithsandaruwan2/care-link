import SwiftUI

struct FaceIDView: View {
    var biometricName: String = "Face ID"
    var onAuthenticate: () -> Void
    var onCancel: () -> Void

    @State private var animate = false

    var body: some View {
        VStack(spacing: CLTheme.spacingLG) {
            Spacer()

            VStack(spacing: CLTheme.spacingLG) {
                ZStack {
                    Circle()
                        .fill(CLTheme.backgroundSecondary)
                        .frame(width: 100, height: 100)
                        .scaleEffect(animate ? 1.0 : 0.9)

                    Image(systemName: "faceid")
                        .font(.system(size: 48))
                        .foregroundStyle(CLTheme.primaryNavy)
                        .symbolEffect(.pulse, value: animate)
                }

                VStack(spacing: CLTheme.spacingSM) {
                    Text("\(biometricName) for CareLink")
                        .font(CLTheme.title2Font)
                        .foregroundStyle(CLTheme.textPrimary)

                    Text("Confirm your identity to access\nyour private health records.")
                        .font(CLTheme.bodyFont)
                        .foregroundStyle(CLTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: CLTheme.spacingMD) {
                    CLButton(title: "Try Again") {
                        onAuthenticate()
                    }

                    Button("Cancel") {
                        onCancel()
                    }
                    .font(CLTheme.headlineFont)
                    .foregroundStyle(CLTheme.accentBlue)
                }
                .padding(.horizontal, CLTheme.spacingLG)
            }
            .padding(CLTheme.spacingXL)
            .background(CLTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: CLTheme.cornerRadiusXL))
            .shadow(color: CLTheme.shadowHeavy, radius: 20)
            .padding(.horizontal, CLTheme.spacingXL)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.4))
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                animate = true
            }
        }
    }
}

#Preview {
    FaceIDView(onAuthenticate: {}, onCancel: {})
}
