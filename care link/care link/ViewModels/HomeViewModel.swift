import SwiftUI

@Observable
final class HomeViewModel {
    enum SortOption: String, CaseIterable {
        case recommended = "Recommended"
        case rating = "Highest Rated"
        case nearest = "Nearest"
        case priceLowToHigh = "Price: Low to High"
    }

    var caregivers: [Caregiver] = []
    var filteredCaregivers: [Caregiver] = []
    var recommendedCaregivers: [Caregiver] = []
    var bookingHistory: [Booking] = []
    var searchText = ""
    var selectedCategory: Caregiver.CareCategory = .all
    var selectedSort: SortOption = .recommended
    var budgetFilterEnabled = false
    var maxBudget: Double = 120
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

        if budgetFilterEnabled {
            filteredCaregivers = filteredCaregivers.filter { $0.hourlyRate <= maxBudget }
        }

        if selectedSort == .recommended, !recommendedCaregivers.isEmpty {
            let rankIndexById = Dictionary(uniqueKeysWithValues: recommendedCaregivers.enumerated().map { ($1.id, $0) })
            filteredCaregivers.sort {
                (rankIndexById[$0.id] ?? Int.max) < (rankIndexById[$1.id] ?? Int.max)
            }
        } else {
            switch selectedSort {
            case .recommended:
                break
            case .rating:
                filteredCaregivers.sort { $0.rating > $1.rating }
            case .nearest:
                filteredCaregivers.sort { $0.distance < $1.distance }
            case .priceLowToHigh:
                filteredCaregivers.sort { $0.hourlyRate < $1.hourlyRate }
            }
        }
    }

    func updateRecommendations(
        recommendationService: CoreMLRecommendationService,
        bookingHistory: [Booking] = []
    ) {
        self.bookingHistory = bookingHistory
        recommendedCaregivers = recommendationService.rankCaregivers(
            caregivers,
            context: CaregiverRecommendationContext(
                preferredCategory: selectedCategory != .all ? selectedCategory : nil,
                maxBudget: nil,
                bookingHistory: bookingHistory
            )
        )
        applyFilters()
    }

    func selectCategory(_ category: Caregiver.CareCategory) {
        selectedCategory = category
        applyFilters()
    }
}
