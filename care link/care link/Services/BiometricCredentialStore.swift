import Foundation
import Security

/// Stores email/password in the Keychain for Face ID / Touch ID–gated sign-in after the first successful password login.
enum BiometricCredentialStore {
    private static let service = "com.carelink.biometricLogin"
    private static let account = "primaryCredentials"
    /// Non-secret hint for the login UI (email only). Password stays in Keychain.
    private static let lastUsedEmailKey = "carelink.lastUsedLoginEmail"

    static var lastUsedEmailForDisplay: String? {
        let s = UserDefaults.standard.string(forKey: lastUsedEmailKey)
        return (s?.isEmpty == false) ? s : nil
    }

    private struct Payload: Codable {
        let email: String
        let password: String
    }

    static var hasCredentials: Bool {
        loadCredentials() != nil
    }

    static func save(email: String, password: String) throws {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let payload = Payload(email: trimmedEmail, password: password)
        let data = try JSONEncoder().encode(payload)

        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(base as CFDictionary)

        var add = base
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
        UserDefaults.standard.set(trimmedEmail, forKey: lastUsedEmailKey)
    }

    static func loadCredentials() -> (email: String, password: String)? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data,
              let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
            return nil
        }
        return (payload.email, payload.password)
    }

    static func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        UserDefaults.standard.removeObject(forKey: lastUsedEmailKey)
    }

    /// If Keychain has credentials but the display email was never stored (older installs), copy email into UserDefaults once.
    static func syncDisplayEmailFromKeychainIfNeeded() {
        guard lastUsedEmailForDisplay == nil, hasCredentials, let email = loadCredentials()?.email else { return }
        UserDefaults.standard.set(email, forKey: lastUsedEmailKey)
    }
}
