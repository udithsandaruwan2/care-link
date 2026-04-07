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

    func checkAvailability() {
        let context = LAContext()
        var error: NSError?
        isAvailable = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        biometricType = context.biometryType
    }

    func authenticate() async -> Bool {
        let context = LAContext()
        context.localizedReason = "Confirm your identity to access your private health records."
        context.localizedCancelTitle = "Cancel"

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Confirm your identity to access your private health records."
            )
            return success
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
        default: return "Biometrics"
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
