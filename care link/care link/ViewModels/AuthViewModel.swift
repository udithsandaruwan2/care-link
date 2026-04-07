import SwiftUI

@Observable
final class AuthViewModel {
    var email = ""
    var password = ""
    var confirmPassword = ""
    var isLoading = false
    var errorMessage: String?
    var showError = false
    var isSignUpMode = false

    var isFormValid: Bool {
        let emailValid = email.contains("@") && email.contains(".")
        if isSignUpMode {
            return emailValid && password.count >= 6 && password == confirmPassword
        }
        return emailValid && password.count >= 6
    }

    @MainActor
    func signIn(authService: AuthService) async -> SignInResult {
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty else {
            showErrorMessage("Please enter your email address.")
            return .failed
        }
        guard password.count >= 6 else {
            showErrorMessage("Password must be at least 6 characters.")
            return .failed
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await authService.signIn(email: email.trimmingCharacters(in: .whitespaces).lowercased(), password: password)
            let isNewUser = authService.userProfile == nil
            return isNewUser ? .newUser : .existingUser
        } catch {
            showErrorMessage(friendlyError(error))
            return .failed
        }
    }

    @MainActor
    func signUp(authService: AuthService) async -> SignInResult {
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty else {
            showErrorMessage("Please enter your email address.")
            return .failed
        }
        guard password.count >= 6 else {
            showErrorMessage("Password must be at least 6 characters.")
            return .failed
        }
        guard password == confirmPassword else {
            showErrorMessage("Passwords do not match.")
            return .failed
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await authService.signUp(email: email.trimmingCharacters(in: .whitespaces).lowercased(), password: password)
            return .newUser
        } catch {
            showErrorMessage(friendlyError(error))
            return .failed
        }
    }

    @MainActor
    func handleGoogleSignIn(authService: AuthService, idToken: String, accessToken: String) async -> SignInResult {
        isLoading = true
        defer { isLoading = false }

        do {
            try await authService.signInWithGoogle(idToken: idToken, accessToken: accessToken)
            let isNewUser = authService.userProfile == nil
            return isNewUser ? .newUser : .existingUser
        } catch {
            showErrorMessage(friendlyError(error))
            return .failed
        }
    }

    @MainActor
    func resetPassword(authService: AuthService) async -> Bool {
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty else {
            showErrorMessage("Please enter your email address to reset password.")
            return false
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await authService.sendPasswordReset(email: email.trimmingCharacters(in: .whitespaces).lowercased())
            return true
        } catch {
            showErrorMessage(friendlyError(error))
            return false
        }
    }

    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }

    private func friendlyError(_ error: Error) -> String {
        let nsError = error as NSError
        switch nsError.code {
        case 17008: return "Invalid email address format."
        case 17009: return "Incorrect password. Please try again."
        case 17011: return "No account found with this email."
        case 17007: return "An account already exists with this email."
        case 17026: return "Password must be at least 6 characters."
        case 17010: return "Too many attempts. Please try later."
        default: return error.localizedDescription
        }
    }

    enum SignInResult {
        case newUser
        case existingUser
        case failed
    }
}
