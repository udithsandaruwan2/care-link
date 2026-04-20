import SwiftUI

@Observable
final class CaregiverPortalViewModel {
    var appointments: [Booking] = []
    var pendingRequests: [Booking] = []
    var upcomingAppointments: [Booking] = []
    var completedAppointments: [Booking] = []
    var caregiverProfile: Caregiver?
    var riskByBookingId: [String: BookingRiskAssessment] = [:]
    var isLoading = false
    var errorMessage: String?

    var todayAppointmentCount: Int {
        let calendar = Calendar.current
        return appointments.filter { calendar.isDateInToday($0.date) && $0.status != .cancelled }.count
    }

    var totalEarnings: Double {
        completedAppointments.reduce(0) { $0 + $1.totalCost }
    }

    func loadAppointments(
        caregiverId: String,
        firestoreService: FirestoreService,
        riskService: CoreMLBookingRiskService
    ) async {
        isLoading = true
        defer { isLoading = false }

        do {
            appointments = try await firestoreService.fetchCaregiverBookings(for: caregiverId)
            categorizeAppointments()
            updatePendingRiskAssessments(riskService: riskService)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func categorizeAppointments() {
        pendingRequests = appointments.filter { $0.status.needsCaregiverAction }
        upcomingAppointments = appointments.filter { $0.status == .confirmed || $0.status == .inProgress }
        completedAppointments = appointments.filter { $0.status == .completed }
    }

    private func updatePendingRiskAssessments(riskService: CoreMLBookingRiskService) {
        var map: [String: BookingRiskAssessment] = [:]
        for pending in pendingRequests {
            let history = appointments.filter { $0.userId == pending.userId && $0.id != pending.id }
            map[pending.id] = riskService.assessRisk(booking: pending, userHistory: history)
        }
        riskByBookingId = map
    }

    func acceptBooking(bookingId: String, firestoreService: FirestoreService) async {
        do {
            try await firestoreService.updateBookingStatus(bookingId: bookingId, status: .confirmed)
            if let index = appointments.firstIndex(where: { $0.id == bookingId }) {
                appointments[index].status = .confirmed
                try? await firestoreService.upsertConnectionForBooking(
                    booking: appointments[index],
                    status: .approved
                )
            }
            categorizeAppointments()
            riskByBookingId.removeValue(forKey: bookingId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func rejectBooking(bookingId: String, firestoreService: FirestoreService) async {
        do {
            try await firestoreService.updateBookingStatus(bookingId: bookingId, status: .cancelled)
            if let index = appointments.firstIndex(where: { $0.id == bookingId }) {
                try? await firestoreService.upsertConnectionForBooking(
                    booking: appointments[index],
                    status: .rejected
                )
                appointments[index].status = .cancelled
            }
            categorizeAppointments()
            riskByBookingId.removeValue(forKey: bookingId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func completeBooking(bookingId: String, firestoreService: FirestoreService) async {
        do {
            try await firestoreService.updateBookingStatus(bookingId: bookingId, status: .completed)
            if let index = appointments.firstIndex(where: { $0.id == bookingId }) {
                appointments[index].status = .completed
            }
            categorizeAppointments()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateProfile(caregiver: Caregiver, firestoreService: FirestoreService) async {
        do {
            try await firestoreService.updateCaregiverProfile(caregiver)
            caregiverProfile = caregiver
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
