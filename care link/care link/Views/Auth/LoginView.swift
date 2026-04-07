import SwiftUI
import FirebaseCore
import FirebaseAuth
import GoogleSignIn

struct LoginView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = AuthViewModel()
    @State private var showResetAlert = false
    @State private var resetSent = false
    @FocusState private var focusedField: Field?

    private enum Field { case email, password, confirm }

    var body: some View {
        ScrollView {
            VStack(spacing: CLTheme.spacingLG) {
                Spacer(minLength: CLTheme.spacingXL)
                branding
                formSection
                actionButtons
                dividerRow
                googleSignInButton
                toggleModeButton
                Spacer(minLength: CLTheme.spacingLG)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .background(CLTheme.backgroundPrimary)
        .alert("Notice", isPresented: $viewModel.showError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert("Password Reset", isPresented: $showResetAlert) {
            Button("OK") {}
        } message: {
            Text(resetSent
                 ? "A password reset link has been sent to \(viewModel.email)."
                 : "Enter your email above, then tap Forgot Password.")
        }
    }

    // MARK: - Branding

    private var branding: some View {
        VStack(spacing: CLTheme.spacingMD) {
            ZStack {
                Circle()
                    .fill(CLTheme.lightBlue)
                    .frame(width: 80, height: 80)
                Image(systemName: "cross.fill")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(CLTheme.primaryNavy)
            }

            Text("CareLink")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(CLTheme.primaryNavy)

            Text(viewModel.isSignUpMode ? "Create your account" : "Welcome back")
                .font(CLTheme.bodyFont)
                .foregroundStyle(CLTheme.textSecondary)
        }
    }

    // MARK: - Form

    private var formSection: some View {
        VStack(spacing: CLTheme.spacingMD) {
            VStack(alignment: .leading, spacing: CLTheme.spacingXS) {
                Text("EMAIL")
                    .font(CLTheme.smallFont)
                    .foregroundStyle(CLTheme.textTertiary)
                    .tracking(1)

                HStack(spacing: CLTheme.spacingSM) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(CLTheme.textTertiary)
                        .frame(width: 24)

                    TextField("your@email.com", text: $viewModel.email)
                        .font(CLTheme.bodyFont)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($focusedField, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }
                }
                .padding(.horizontal, CLTheme.spacingMD)
                .frame(height: 54)
                .background(CLTheme.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: CLTheme.cornerRadiusMD))
            }

            VStack(alignment: .leading, spacing: CLTheme.spacingXS) {
                Text("PASSWORD")
                    .font(CLTheme.smallFont)
                    .foregroundStyle(CLTheme.textTertiary)
                    .tracking(1)

                HStack(spacing: CLTheme.spacingSM) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(CLTheme.textTertiary)
                        .frame(width: 24)

                    SecureField("Enter password", text: $viewModel.password)
                        .font(CLTheme.bodyFont)
                        .textContentType(viewModel.isSignUpMode ? .newPassword : .password)
                        .focused($focusedField, equals: .password)
                        .submitLabel(viewModel.isSignUpMode ? .next : .go)
                        .onSubmit {
                            if viewModel.isSignUpMode {
                                focusedField = .confirm
                            } else {
                                performSignIn()
                            }
                        }
                }
                .padding(.horizontal, CLTheme.spacingMD)
                .frame(height: 54)
                .background(CLTheme.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: CLTheme.cornerRadiusMD))
            }

            if viewModel.isSignUpMode {
                VStack(alignment: .leading, spacing: CLTheme.spacingXS) {
                    Text("CONFIRM PASSWORD")
                        .font(CLTheme.smallFont)
                        .foregroundStyle(CLTheme.textTertiary)
                        .tracking(1)

                    HStack(spacing: CLTheme.spacingSM) {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 16))
                            .foregroundStyle(CLTheme.textTertiary)
                            .frame(width: 24)

                        SecureField("Re-enter password", text: $viewModel.confirmPassword)
                            .font(CLTheme.bodyFont)
                            .textContentType(.newPassword)
                            .focused($focusedField, equals: .confirm)
                            .submitLabel(.go)
                            .onSubmit { performSignUp() }
                    }
                    .padding(.horizontal, CLTheme.spacingMD)
                    .frame(height: 54)
                    .background(CLTheme.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: CLTheme.cornerRadiusMD))
                }
            }

            if !viewModel.isSignUpMode {
                HStack {
                    Spacer()
                    Button("Forgot Password?") {
                        Task {
                            resetSent = await viewModel.resetPassword(authService: appState.authService)
                            showResetAlert = true
                        }
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(CLTheme.accentBlue)
                }
            }
        }
        .padding(.horizontal, CLTheme.spacingLG)
        .animation(.easeInOut(duration: 0.25), value: viewModel.isSignUpMode)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        CLButton(
            title: viewModel.isSignUpMode ? "Create Account" : "Sign In",
            icon: viewModel.isSignUpMode ? "person.badge.plus" : "arrow.right",
            isLoading: viewModel.isLoading
        ) {
            if viewModel.isSignUpMode {
                performSignUp()
            } else {
                performSignIn()
            }
        }
        .padding(.horizontal, CLTheme.spacingLG)
    }

    // MARK: - Divider

    private var dividerRow: some View {
        HStack(spacing: CLTheme.spacingMD) {
            Rectangle()
                .fill(CLTheme.divider)
                .frame(height: 1)
            Text("or")
                .font(CLTheme.captionFont)
                .foregroundStyle(CLTheme.textTertiary)
            Rectangle()
                .fill(CLTheme.divider)
                .frame(height: 1)
        }
        .padding(.horizontal, CLTheme.spacingLG)
    }

    // MARK: - Google Sign-In

    private var googleSignInButton: some View {
        Button {
            performGoogleSignIn()
        } label: {
            HStack(spacing: CLTheme.spacingSM) {
                Image(systemName: "g.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                Text("Continue with Google")
                    .font(CLTheme.headlineFont)
            }
            .foregroundStyle(CLTheme.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(CLTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: CLTheme.cornerRadiusFull))
            .overlay {
                RoundedRectangle(cornerRadius: CLTheme.cornerRadiusFull)
                    .stroke(CLTheme.divider, lineWidth: 1.5)
            }
        }
        .padding(.horizontal, CLTheme.spacingLG)
    }

    // MARK: - Toggle Mode

    private var toggleModeButton: some View {
        HStack(spacing: 4) {
            Text(viewModel.isSignUpMode ? "Already have an account?" : "Don't have an account?")
                .font(CLTheme.bodyFont)
                .foregroundStyle(CLTheme.textSecondary)
            Button(viewModel.isSignUpMode ? "Sign In" : "Sign Up") {
                withAnimation {
                    viewModel.isSignUpMode.toggle()
                    viewModel.confirmPassword = ""
                }
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(CLTheme.accentBlue)
        }
        .padding(.top, CLTheme.spacingSM)
    }

    // MARK: - Actions

    private func performSignIn() {
        focusedField = nil
        Task {
            let result = await viewModel.signIn(authService: appState.authService)
            handleResult(result)
        }
    }

    private func performSignUp() {
        focusedField = nil
        Task {
            let result = await viewModel.signUp(authService: appState.authService)
            handleResult(result)
        }
    }

    private func performGoogleSignIn() {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            viewModel.errorMessage = "Google Sign-In is not configured. Please update GoogleService-Info.plist."
            viewModel.showError = true
            return
        }

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            viewModel.errorMessage = "Unable to present Google Sign-In."
            viewModel.showError = true
            return
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        GIDSignIn.sharedInstance.signIn(withPresenting: rootVC) { result, error in
            if let error {
                viewModel.errorMessage = error.localizedDescription
                viewModel.showError = true
                return
            }

            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                viewModel.errorMessage = "Failed to get Google credentials."
                viewModel.showError = true
                return
            }

            Task {
                let signInResult = await viewModel.handleGoogleSignIn(
                    authService: appState.authService,
                    idToken: idToken,
                    accessToken: user.accessToken.tokenString
                )
                handleResult(signInResult)
            }
        }
    }

    private func handleResult(_ result: AuthViewModel.SignInResult) {
        switch result {
        case .newUser:
            appState.needsProfileSetup = true
            appState.isAuthenticated = true
            appState.showWelcome = false
        case .existingUser:
            if let profile = appState.authService.userProfile {
                appState.currentUserRole = profile.role
                if profile.role == .caregiver && !profile.hasCompletedCaregiverRegistration {
                    appState.needsCaregiverRegistration = true
                }
                appState.startChatListener()
            }
            appState.isAuthenticated = true
            appState.showWelcome = false
        case .failed:
            break
        }
    }
}

#Preview {
    LoginView()
        .environment(AppState())
}
