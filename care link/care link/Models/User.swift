import Foundation

struct CLUser: Identifiable, Codable, Sendable {
    let id: String
    var fullName: String
    var email: String
    var phoneNumber: String
    var role: UserRole
    var profileImageURL: String
    var address: String
    var emergencyContact: String
    var createdAt: Date
    var isBiometricEnabled: Bool
    var hasCompletedCaregiverRegistration: Bool

    enum UserRole: String, Codable, Sendable, CaseIterable {
        case user = "user"
        case caregiver = "caregiver"
    }

    init(id: String, fullName: String, email: String, phoneNumber: String, role: UserRole, profileImageURL: String, address: String, emergencyContact: String = "", createdAt: Date, isBiometricEnabled: Bool, hasCompletedCaregiverRegistration: Bool) {
        self.id = id
        self.fullName = fullName
        self.email = email
        self.phoneNumber = phoneNumber
        self.role = role
        self.profileImageURL = profileImageURL
        self.address = address
        self.emergencyContact = emergencyContact
        self.createdAt = createdAt
        self.isBiometricEnabled = isBiometricEnabled
        self.hasCompletedCaregiverRegistration = hasCompletedCaregiverRegistration
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        fullName = try container.decodeIfPresent(String.self, forKey: .fullName) ?? ""
        email = try container.decodeIfPresent(String.self, forKey: .email) ?? ""
        phoneNumber = try container.decodeIfPresent(String.self, forKey: .phoneNumber) ?? ""
        role = try container.decodeIfPresent(UserRole.self, forKey: .role) ?? .user
        profileImageURL = try container.decodeIfPresent(String.self, forKey: .profileImageURL) ?? ""
        address = try container.decodeIfPresent(String.self, forKey: .address) ?? ""
        emergencyContact = try container.decodeIfPresent(String.self, forKey: .emergencyContact) ?? ""
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        isBiometricEnabled = try container.decodeIfPresent(Bool.self, forKey: .isBiometricEnabled) ?? false
        hasCompletedCaregiverRegistration = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedCaregiverRegistration) ?? false
    }
}
