import Foundation

@Observable
final class RecommendationService {
    func getRecommendedCaregivers(
        from caregivers: [Caregiver],
        userPreferredCategory: Caregiver.CareCategory? = nil,
        maxBudget: Double? = nil,
        bookingHistory: [Booking] = []
    ) -> [Caregiver] {
        var scored: [(caregiver: Caregiver, score: Double)] = []

        let bookedCaregiverIds = Set(bookingHistory.map { $0.caregiverId })

        for caregiver in caregivers {
            var score: Double = 0

            // Rating weight (0-5 normalized to 0-25)
            score += caregiver.rating * 5

            // Experience weight (years * 2, max 20)
            score += min(Double(caregiver.experienceYears) * 2, 20)

            // Proximity weight (closer = higher, max 20)
            let distanceScore = max(0, 20 - caregiver.distance * 4)
            score += distanceScore

            // Review count weight (normalized, max 15)
            score += min(Double(caregiver.reviewCount) / 10.0, 15)

            // Category match bonus
            if let preferred = userPreferredCategory, caregiver.category == preferred {
                score += 15
            }

            // Budget fit bonus
            if let budget = maxBudget, caregiver.hourlyRate <= budget {
                score += 10
            }

            // Previously booked bonus (familiarity)
            if bookedCaregiverIds.contains(caregiver.id) {
                score += 8
            }

            // Verified bonus
            if caregiver.isVerified {
                score += 5
            }

            scored.append((caregiver, score))
        }

        return scored
            .sorted { $0.score > $1.score }
            .map { $0.caregiver }
    }
}
