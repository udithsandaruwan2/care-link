import Foundation
import FirebaseAuth
import FirebaseFirestore
import AuthenticationServices
import CryptoKit

@Observable
final class AuthService {
    var currentUser: FirebaseAuth.User?
    var userProfile: CLUser?
    var isAuthenticated = false
    var errorMessage: String?

    private var db: Firestore { Firestore.firestore() }

    func checkCurrentUser() {
        currentUser = Auth.auth().currentUser
        isAuthenticated = currentUser != nil
        if let uid = currentUser?.uid {
            Task { await fetchUserProfile(uid: uid) }
        }
    }

    // MARK: - Email / Password

    func signIn(email: String, password: String) async throws {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        currentUser = result.user
        isAuthenticated = true
        await fetchUserProfile(uid: result.user.uid)
    }

    func signUp(email: String, password: String) async throws {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        currentUser = result.user
        isAuthenticated = true
    }

    // MARK: - Google Sign-In

    func signInWithGoogle(idToken: String, accessToken: String) async throws {
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: accessToken
        )
        let result = try await Auth.auth().signIn(with: credential)
        currentUser = result.user
        isAuthenticated = true
        await fetchUserProfile(uid: result.user.uid)
    }

    // MARK: - Profile Management

    func createNewUserProfile(fullName: String, email: String, role: CLUser.UserRole) async throws {
        guard let user = currentUser else { return }

        let newUser = CLUser(
            id: user.uid,
            fullName: fullName,
            email: email,
            phoneNumber: user.phoneNumber ?? "",
            role: role,
            profileImageURL: user.photoURL?.absoluteString ?? "",
            address: "",
            emergencyContact: "",
            createdAt: Date(),
            isBiometricEnabled: false,
            hasCompletedCaregiverRegistration: false
        )

        let data = try Firestore.Encoder().encode(newUser)
        try await db.collection("users").document(user.uid).setData(data)
        userProfile = newUser
    }

    func fetchUserProfile(uid: String) async {
        do {
            let document = try await db.collection("users").document(uid).getDocument()
            if document.exists {
                userProfile = try document.data(as: CLUser.self)
            } else {
                userProfile = nil
            }
        } catch {
            errorMessage = error.localizedDescription
            userProfile = nil
        }
    }

    func updateUserProfile(_ user: CLUser) async throws {
        let data = try Firestore.Encoder().encode(user)
        try await db.collection("users").document(user.id).setData(data, merge: true)
        userProfile = user
    }

    // MARK: - Password Reset

    func sendPasswordReset(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }

    // MARK: - Sign Out & Delete

    func signOut() throws {
        try Auth.auth().signOut()
        currentUser = nil
        userProfile = nil
        isAuthenticated = false
    }

    func deleteAccount() async throws {
        guard let user = currentUser else { return }
        try await db.collection("users").document(user.uid).delete()
        try await user.delete()
        currentUser = nil
        userProfile = nil
        isAuthenticated = false
    }
}
