import Foundation

enum CaregiverIdentityMatcher {
    private static let honorifics: Set<String> = [
        "dr",
        "doctor",
        "mr",
        "mrs",
        "ms",
        "miss"
    ]

    static func normalizedName(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private static func canonicalName(_ value: String) -> String {
        let lowered = normalizedName(value)
        let alphanumericWords = lowered
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        let trimmedWords = alphanumericWords.drop(while: { honorifics.contains($0) })
        return trimmedWords.joined(separator: " ")
    }

    private static func namesAreEquivalent(_ lhs: String, _ rhs: String) -> Bool {
        let left = canonicalName(lhs)
        let right = canonicalName(rhs)
        guard !left.isEmpty, !right.isEmpty else { return false }
        if left == right { return true }
        // Allow "john doe" to match "dr john doe" / "john doe md" style variants.
        return left.count >= 4 && right.count >= 4 && (left.contains(right) || right.contains(left))
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
        guard !normalized.isEmpty else { return false }
        if knownNames.contains(normalized) { return true }
        return knownNames.contains { namesAreEquivalent($0, normalized) }
    }
}

