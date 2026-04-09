import SwiftUI
import MapKit

@Observable
final class MapViewModel {
    var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 6.9271, longitude: 79.8612),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    var caregivers: [Caregiver] = []
    var selectedCaregiver: Caregiver?
    var searchText = ""
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
            if let first = caregivers.first {
                cameraPosition = .region(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: first.latitude, longitude: first.longitude),
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                ))
            }
        } catch {
            caregivers = []
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
}
