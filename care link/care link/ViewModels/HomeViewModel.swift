import SwiftUI

@Observable
final class HomeViewModel {
    var caregivers: [Caregiver] = []
    var filteredCaregivers: [Caregiver] = []
    var recommendedCaregivers: [Caregiver] = []
    var searchText = ""
    var selectedCategory: Caregiver.CareCategory = .all
    var isLoading = false
    var errorMessage: String?

    func loadCaregivers(firestoreService: FirestoreService) async {
        isLoading = true
        defer { isLoading = false }

        do {
            caregivers = try await firestoreService.fetchCaregivers()
            applyFilters()
        } catch {
            errorMessage = error.localizedDescription
            caregivers = []
            applyFilters()
        }
    }

    func applyFilters() {
        filteredCaregivers = caregivers

        if selectedCategory != .all {
            filteredCaregivers = filteredCaregivers.filter { $0.category == selectedCategory }
        }

        if !searchText.isEmpty {
            filteredCaregivers = filteredCaregivers.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.specialty.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    func updateRecommendations(
        recommendationService: RecommendationService,
        bookingHistory: [Booking] = []
    ) {
        recommendedCaregivers = recommendationService.getRecommendedCaregivers(
            from: caregivers,
            userPreferredCategory: selectedCategory != .all ? selectedCategory : nil,
            bookingHistory: bookingHistory
        )
    }

    func selectCategory(_ category: Caregiver.CareCategory) {
        selectedCategory = category
        applyFilters()
    }
}
