import Foundation

enum CaregiverIdentityMatcher {
    static func normalizedName(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    static func matches(
        caregiverId: String,
        caregiverName: String,
        knownIds: Set<String>,
        knownNames: Set<String>
    ) -> Bool {
        if knownIds.contains(caregiverId) {
            return true
        }
        let normalized = normalizedName(caregiverName)
        return !normalized.isEmpty && knownNames.contains(normalized)
    }
}

