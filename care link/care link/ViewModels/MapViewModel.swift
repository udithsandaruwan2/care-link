import SwiftUI
import MapKit

@Observable
final class MapViewModel {
    var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 6.9271, longitude: 79.8612),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    var caregivers: [Caregiver] = []
    var filteredCaregivers: [Caregiver] = []
    var selectedCaregiver: Caregiver?
    var searchText = ""
    var selectedSpecialtyFilter: String?
    var isLoading = false
    var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 6.9271, longitude: 79.8612),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    )

    func loadCaregivers(firestoreService: FirestoreService) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let all = try await firestoreService.fetchCaregivers()
            caregivers = all.filter { $0.latitude != 0 && $0.longitude != 0 }
            applySearch()
            if let first = caregivers.first {
                cameraPosition = .region(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: first.latitude, longitude: first.longitude),
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                ))
            }
        } catch {
            caregivers = []
            filteredCaregivers = []
        }
    }

    func selectCaregiver(_ caregiver: Caregiver) {
        selectedCaregiver = caregiver
        let coordinate = CLLocationCoordinate2D(latitude: caregiver.latitude, longitude: caregiver.longitude)
        withAnimation {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                )
            )
        }
    }

    func clearCaregiverSelection() {
        withAnimation(.spring(response: 0.3)) {
            selectedCaregiver = nil
        }
    }

    func centerOnUserLocation(_ location: CLLocationCoordinate2D) {
        withAnimation {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: location,
                    span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
                )
            )
        }
    }

    var specialtySuggestions: [String] {
        let all = Set(caregivers.map(\.specialty).filter { !$0.isEmpty })
        return Array(all).sorted().prefix(8).map { $0 }
    }

    func selectSpecialtyFilter(_ specialty: String?) {
        selectedSpecialtyFilter = specialty
        applySearch()
    }

    func applySearch() {
        var result = caregivers
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if let specialty = selectedSpecialtyFilter, !specialty.isEmpty {
            result = result.filter { $0.specialty.caseInsensitiveCompare(specialty) == .orderedSame }
        }

        if !query.isEmpty {
            result = result.filter {
                $0.name.lowercased().contains(query) ||
                $0.specialty.lowercased().contains(query)
            }
        }

        filteredCaregivers = result

        if let selectedCaregiver, !filteredCaregivers.contains(where: { $0.id == selectedCaregiver.id }) {
            clearCaregiverSelection()
        }
    }
}
