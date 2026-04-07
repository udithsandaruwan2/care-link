import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if appState.isAuthenticated {
                if appState.needsProfileSetup {
                    NewUserSetupView()
                } else if appState.needsCaregiverRegistration {
                    CaregiverRegistrationView()
                } else {
                    MainTabView()
                }
            } else if appState.showWelcome && !appState.isOnboardingComplete {
                WelcomeView(
                    onGetStarted: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            appState.showWelcome = false
                        }
                    },
                    onSignIn: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            appState.showWelcome = false
                            appState.completeOnboarding()
                        }
                    }
                )
                .transition(.opacity)
            } else if !appState.isOnboardingComplete {
                OnboardingView {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        appState.completeOnboarding()
                    }
                }
                .transition(.slide)
            } else {
                LoginView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.4), value: appState.isAuthenticated)
        .animation(.easeInOut(duration: 0.4), value: appState.showWelcome)
        .animation(.easeInOut(duration: 0.4), value: appState.isOnboardingComplete)
        .animation(.easeInOut(duration: 0.4), value: appState.needsCaregiverRegistration)
        .animation(.easeInOut(duration: 0.4), value: appState.needsProfileSetup)
        .onAppear {
            appState.checkAuthState()
        }
    }
}

#Preview {
    ContentView()
        .environment(AppState())
}
