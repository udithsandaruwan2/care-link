import Foundation
import LocalAuthentication

@Observable
final class BiometricService {
    var isAvailable = false
    var biometricType: LABiometryType = .none
    var errorMessage: String?

    init() {
        checkAvailability()
    }

    /// Uses `.deviceOwnerAuthentication` so Face ID / Touch ID **or the device passcode** is allowed.
    /// This matches the iOS Settings screen and works on the **Simulator** (passcode, or Features → Face ID → Enrolled + Matching Face).
    func checkAvailability() {
        let context = LAContext()
        var error: NSError?
        isAvailable = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
        biometricType = context.biometryType
    }

    func authenticate() async -> Bool {
        let context = LAContext()
        context.localizedReason = "Unlock CareLink to protect your health information."
        context.localizedCancelTitle = "Cancel"

        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Unlock CareLink to protect your health information."
            )
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    var biometricName: String {
        switch biometricType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "Device Passcode"
        }
    }

    /// Shorter label for buttons when only passcode is available (e.g. Simulator without Face ID enrolled).
    var unlockButtonLabel: String {
        switch biometricType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "Passcode"
        }
    }

    var biometricIcon: String {
        switch biometricType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        default: return "lock.shield"
        }
    }
}
