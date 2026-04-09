import SwiftUI
import CoreData
import FirebaseAuth

@Observable
final class AppState {
    /// When true (after user opts in), reopening the app with a Firebase session requires unlock via Face ID / Touch ID / passcode.
    static let biometricAppUnlockPreferenceKey = "carelink.biometricAppUnlockEnabled"

    var isOnboardingComplete: Bool = UserDefaults.standard.bool(forKey: "isOnboardingComplete") {
        didSet { UserDefaults.standard.set(isOnboardingComplete, forKey: "isOnboardingComplete") }
    }

    var isAuthenticated = false
    var showWelcome: Bool = !UserDefaults.standard.bool(forKey: "isOnboardingComplete")
    var currentUserRole: CLUser.UserRole = .user
    var needsCaregiverRegistration = false
    var needsProfileSetup = false
    /// When true, a full-screen Face ID / Touch ID gate covers the app (after backgrounding or cold start with saved biometric sign-in).
    var isBiometricAppLocked = false
    /// Prevents a late profile fetch from re-arming the lock after the user has already unlocked.
    private var didRunProfileBiometricLockPass = false
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
            biometricService.checkAvailability()
            applyBiometricLockOnColdStartIfNeeded()
            Task {
                await authService.fetchUserProfile(uid: user.uid)
                await MainActor.run {
                    if let profile = authService.userProfile {
                        currentUserRole = profile.role
                        if profile.role == .caregiver && !profile.hasCompletedCaregiverRegistration {
                            needsCaregiverRegistration = true
                        }
                        startChatListener()
                    } else {
                        needsProfileSetup = true
                    }
                    applyBiometricLockAfterProfileIfNeeded()
                }
            }
        } else {
            didRunProfileBiometricLockPass = false
        }
    }

    /// True when biometric app lock is explicitly enabled locally and on the user profile.
    func shouldUseBiometricAppLock() -> Bool {
        guard isAuthenticated else { return false }
        biometricService.checkAvailability()
        guard biometricService.isAvailable else { return false }
        let localEnabled = UserDefaults.standard.bool(forKey: Self.biometricAppUnlockPreferenceKey)
        return localEnabled && authService.userProfile?.isBiometricEnabled == true
    }

    /// Lock as soon as we know a session should be shielded (Keychain / preference before profile loads).
    private func applyBiometricLockOnColdStartIfNeeded() {
        guard isAuthenticated else { return }
        biometricService.checkAvailability()
        guard biometricService.isAvailable else { return }
        if shouldUseBiometricAppLock() {
            isBiometricAppLocked = true
        }
    }

    /// Locks once after profile load when shielding comes only from Firestore (no Keychain / local pref yet).
    private func applyBiometricLockAfterProfileIfNeeded() {
        guard !didRunProfileBiometricLockPass else { return }
        didRunProfileBiometricLockPass = true

        guard isAuthenticated else { return }
        biometricService.checkAvailability()
        guard biometricService.isAvailable else { return }
        guard shouldUseBiometricAppLock() else { return }

        isBiometricAppLocked = true
    }

    /// Call when the app moves to background so the next foreground requires Face ID / Touch ID.
    func lockAppForBiometricsIfNeeded() {
        guard shouldUseBiometricAppLock() else { return }
        isBiometricAppLocked = true
    }

    @MainActor
    func unlockAppWithBiometrics() async {
        guard isBiometricAppLocked else { return }
        biometricService.checkAvailability()
        guard biometricService.isAvailable else {
            isBiometricAppLocked = false
            return
        }
        let ok = await biometricService.authenticate()
        if ok {
            isBiometricAppLocked = false
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
        isBiometricAppLocked = false
        didRunProfileBiometricLockPass = false
        UserDefaults.standard.removeObject(forKey: Self.biometricAppUnlockPreferenceKey)
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

        BiometricCredentialStore.clear()

        isBiometricAppLocked = false
        didRunProfileBiometricLockPass = false
        isAuthenticated = false
        needsCaregiverRegistration = false
        needsProfileSetup = false
        isOnboardingComplete = false
        showWelcome = true
        currentUserRole = .user
    }
}
