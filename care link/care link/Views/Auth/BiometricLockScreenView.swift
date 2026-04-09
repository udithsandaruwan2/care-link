import SwiftUI

/// Full-screen gate shown when the app was backgrounded and the user has Face ID / Touch ID enabled.
struct BiometricLockScreenView: View {
    @Environment(AppState.self) private var appState
    @State private var pulse = false
    @State private var isMatching = false

    var body: some View {
        ZStack {
            CLTheme.primaryNavy
                .ignoresSafeArea()

            VStack(spacing: CLTheme.spacingXL) {
                Spacer(minLength: CLTheme.spacingXL)

                dynamicIslandMatcher

                VStack(spacing: CLTheme.spacingSM) {
                    Text("CareLink is locked")
                        .font(CLTheme.titleFont)
                        .foregroundStyle(.white)

                    Text("Face matching starts automatically. If Face ID is unavailable, use Touch ID or your device passcode.")
                        .font(CLTheme.bodyFont)
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, CLTheme.spacingXL)
                }

                CLButton(title: "Unlock with \(appState.biometricService.unlockButtonLabel)", icon: appState.biometricService.biometricIcon) {
                    Task { await appState.unlockAppWithBiometrics() }
                }
                .padding(.horizontal, CLTheme.spacingLG)

                Button("Sign out") {
                    appState.signOut()
                }
                .font(CLTheme.calloutFont)
                .foregroundStyle(.white.opacity(0.75))
                .padding(.top, CLTheme.spacingSM)

                Spacer()
            }
        }
        .task {
            isMatching = true
            await appState.unlockAppWithBiometrics()
            isMatching = false
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    private var dynamicIslandMatcher: some View {
        VStack(spacing: CLTheme.spacingMD) {
            Capsule()
                .fill(.black.opacity(0.85))
                .overlay {
                    HStack(spacing: CLTheme.spacingSM) {
                        Image(systemName: appState.biometricService.biometricIcon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(isMatching ? "Matching identity..." : "Ready to match")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                            Text(appState.biometricService.biometricName)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white.opacity(0.75))
                        }
                        Spacer(minLength: 0)
                        Circle()
                            .fill(isMatching ? CLTheme.tealAccent : CLTheme.lightBlue.opacity(0.75))
                            .frame(width: 8, height: 8)
                            .scaleEffect(isMatching && pulse ? 1.25 : 1)
                    }
                    .padding(.horizontal, CLTheme.spacingMD)
                }
                .frame(maxWidth: 280)
                .frame(height: 52)
                .shadow(color: .black.opacity(0.22), radius: 10, y: 5)

            RoundedRectangle(cornerRadius: CLTheme.cornerRadiusLG, style: .continuous)
                .fill(CLTheme.lightBlue.opacity(0.18))
                .frame(width: 132, height: 132)
                .overlay {
                    RoundedRectangle(cornerRadius: CLTheme.cornerRadiusLG, style: .continuous)
                        .stroke(CLTheme.lightBlue.opacity(0.35), lineWidth: 1.5)
                }
                .overlay {
                    Image(systemName: appState.biometricService.biometricIcon)
                        .font(.system(size: 52))
                        .foregroundStyle(.white)
                        .scaleEffect(isMatching && pulse ? 1.06 : 1)
                }
        }
    }
}

#Preview {
    BiometricLockScreenView()
        .environment(AppState())
}
