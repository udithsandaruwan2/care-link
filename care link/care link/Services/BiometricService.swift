// File responsibility: Defines biometric service logic for the care link app.

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

    /// Check unlock capability; this allows device passcode fallback on some devices/simulator states.
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
            // Handle each state transition explicitly.
            switch laError.code {
            case .biometryLockout, .appCancel, .systemCancel, .invalidContext, .notInteractive:
                isAvailable = true
            // Use a safe fallback when data is missing.
            default:
                isAvailable = false
            }
        } else {
            isAvailable = false
        }
    }

    func authenticate() async -> Bool {
        checkAvailability()
        guard isAvailable else {
            errorMessage = "Face ID is not available or not set up on this device."
            return false
        }
        let context = LAContext()
        context.localizedReason = "Unlock CareLink to protect your health information."
        context.localizedCancelTitle = "Cancel"
        context.localizedFallbackTitle = "Use Passcode"

        do {
            // Prefer biometric first when available.
            return try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Unlock CareLink to protect your health information."
            )
        } catch {
            if let laError = error as? LAError {
                // If biometric-only auth is unavailable right now, fall back to device passcode.
                if laError.code == .biometryLockout ||
                    laError.code == .biometryNotAvailable ||
                    laError.code == .biometryNotEnrolled {
                    do {
                        return try await context.evaluatePolicy(
                            .deviceOwnerAuthentication,
                            localizedReason: "Unlock CareLink to protect your health information."
                        )
                    } catch {
                        if let fallbackError = error as? LAError {
                            errorMessage = fallbackError.localizedDescription
                        } else {
                            errorMessage = error.localizedDescription
                        }
                        return false
                    }
                }
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
