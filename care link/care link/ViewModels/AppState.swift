import SwiftUI
import CoreData
import FirebaseAuth

@Observable
final class AppState {
    var isOnboardingComplete: Bool = UserDefaults.standard.bool(forKey: "isOnboardingComplete") {
        didSet { UserDefaults.standard.set(isOnboardingComplete, forKey: "isOnboardingComplete") }
    }

    var isAuthenticated = false
    var showWelcome: Bool = !UserDefaults.standard.bool(forKey: "isOnboardingComplete")
    var currentUserRole: CLUser.UserRole = .user
    var needsCaregiverRegistration = false
    var needsProfileSetup = false
    var navigationResetToken = UUID()

    let authService = AuthService()
    let firestoreService = FirestoreService()
    let chatService = ChatService()
    let biometricService = BiometricService()
    let notificationService = NotificationService()
    let locationService = LocationService()
    let eventKitService = EventKitService()
    let recommendationService = RecommendationService()

    func checkAuthState() {
        authService.checkCurrentUser()
        if let user = Auth.auth().currentUser {
            isAuthenticated = true
            showWelcome = false
            Task {
                await authService.fetchUserProfile(uid: user.uid)
                if let profile = authService.userProfile {
                    currentUserRole = profile.role
                    if profile.role == .caregiver && !profile.hasCompletedCaregiverRegistration {
                        needsCaregiverRegistration = true
                    }
                    startChatListener()
                } else {
                    needsProfileSetup = true
                }
            }
        }
    }

    func startChatListener() {
        guard let uid = authService.currentUser?.uid else { return }
        chatService.listenToConversations(userId: uid, role: currentUserRole)
    }

    func completeOnboarding() {
        isOnboardingComplete = true
    }

    func resetOnboarding() {
        isOnboardingComplete = false
        showWelcome = true
    }

    func completeCaregiverRegistration() {
        needsCaregiverRegistration = false
        if var profile = authService.userProfile {
            profile.hasCompletedCaregiverRegistration = true
            Task {
                try? await firestoreService.updateUser(profile)
                await authService.fetchUserProfile(uid: profile.id)
            }
        }
    }

    func signOut() {
        chatService.stopAllListeners()
        try? authService.signOut()
        isAuthenticated = false
        needsCaregiverRegistration = false
        needsProfileSetup = false
        showWelcome = !isOnboardingComplete
    }

    func clearAllData() {
        chatService.stopAllListeners()
        try? authService.signOut()

        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys {
            defaults.removeObject(forKey: key)
        }

        let persistence = PersistenceController.shared
        let context = persistence.container.viewContext
        for entityName in ["CachedCaregiver", "UserPreference", "CachedBooking"] {
            let fetch = NSFetchRequest<NSManagedObject>(entityName: entityName)
            if let objects = try? context.fetch(fetch) {
                objects.forEach { context.delete($0) }
            }
        }
        persistence.save()

        isAuthenticated = false
        needsCaregiverRegistration = false
        needsProfileSetup = false
        isOnboardingComplete = false
        showWelcome = true
        currentUserRole = .user
    }
}
