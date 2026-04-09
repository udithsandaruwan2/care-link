import Foundation

struct CaregiverRecommendationContext {
    let preferredCategory: Caregiver.CareCategory?
    let maxBudget: Double?
    let bookingHistory: [Booking]
}

@Observable
final class CoreMLRecommendationService {
    private let modelProvider: CoreMLModelProviding
    private let fallbackService: RecommendationService
    private let modelName = "CaregiverRecommender"
    private let outputKey = "score"

    init(
        modelProvider: CoreMLModelProviding = DefaultCoreMLModelProvider(),
        fallbackService: RecommendationService = RecommendationService()
    ) {
        self.modelProvider = modelProvider
        self.fallbackService = fallbackService
    }

    func rankCaregivers(
        _ caregivers: [Caregiver],
        context: CaregiverRecommendationContext
    ) -> [Caregiver] {
        guard !caregivers.isEmpty else { return [] }

        let mlScored: [(Caregiver, Double)] = caregivers.compactMap { caregiver in
            let features = makeFeatures(for: caregiver, context: context)
            guard let raw = modelProvider.prediction(
                modelName: modelName,
                inputFeatures: features,
                outputKey: outputKey
            ) else {
                return nil
            }
            return (caregiver, raw)
        }

        if mlScored.count == caregivers.count {
            return mlScored.sorted { $0.1 > $1.1 }.map(\.0)
        }

        // If no model or partial prediction, use deterministic fallback to keep UX stable.
        return fallbackService.getRecommendedCaregivers(
            from: caregivers,
            userPreferredCategory: context.preferredCategory,
            maxBudget: context.maxBudget,
            bookingHistory: context.bookingHistory
        )
    }

    private func makeFeatures(
        for caregiver: Caregiver,
        context: CaregiverRecommendationContext
    ) -> [String: Double] {
        let bookedCaregiverIds = Set(context.bookingHistory.map(\.caregiverId))
        return [
            "rating": caregiver.rating,
            "reviewCount": Double(caregiver.reviewCount),
            "experienceYears": Double(caregiver.experienceYears),
            "distanceKm": caregiver.distance,
            "hourlyRate": caregiver.hourlyRate,
            "isVerified": caregiver.isVerified ? 1 : 0,
            "categoryMatch": context.preferredCategory == caregiver.category ? 1 : 0,
            "withinBudget": {
                guard let maxBudget = context.maxBudget else { return 0 }
                return caregiver.hourlyRate <= maxBudget ? 1 : 0
            }(),
            "bookedBefore": bookedCaregiverIds.contains(caregiver.id) ? 1 : 0
        ]
    }
}
