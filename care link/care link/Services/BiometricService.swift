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

    /// Uses device-owner auth so Face ID/Touch ID can fall back to device passcode when needed.
    func checkAvailability() {
        let context = LAContext()
        var error: NSError?
        let canUseBiometrics = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
        biometricType = context.biometryType
        // Keep availability true when hardware exists and is enrolled even if policy is temporarily unavailable.
        // This avoids hiding Face ID UI after transient LAContext failures.
        if canUseBiometrics {
            isAvailable = true
        } else if biometricType != .none, let laError = error.flatMap({ LAError(_nsError: $0) }) {
            switch laError.code {
            case .biometryLockout, .appCancel, .systemCancel, .invalidContext, .notInteractive:
                isAvailable = true
            default:
                isAvailable = false
            }
        } else {
            isAvailable = false
        }
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
            if let laError = error as? LAError {
                switch laError.code {
                case .biometryLockout:
                    errorMessage = "Face ID is temporarily locked. Unlock your phone once, then try again."
                case .biometryNotEnrolled:
                    errorMessage = "Face ID is not set up on this device."
                case .biometryNotAvailable:
                    errorMessage = "Biometric authentication is not available right now."
                case .userCancel, .systemCancel, .appCancel:
                    errorMessage = nil
                default:
                    errorMessage = laError.localizedDescription
                }
            } else {
                errorMessage = error.localizedDescription
            }
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

    /// Label for unlock buttons.
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
