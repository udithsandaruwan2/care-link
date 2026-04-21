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

    func acceptBooking(bookingId: String, caregiverUid: String, firestoreService: FirestoreService) async {
        do {
            let updated = try await firestoreService.applyBookingTransition(
                bookingId: bookingId,
                to: .confirmed,
                actor: .caregiver,
                callerUid: caregiverUid
            )
            if let index = appointments.firstIndex(where: { $0.id == bookingId }) {
                appointments[index] = updated
            }
            categorizeAppointments()
            riskByBookingId.removeValue(forKey: bookingId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func rejectBooking(bookingId: String, caregiverUid: String, firestoreService: FirestoreService) async {
        do {
            let updated = try await firestoreService.applyBookingTransition(
                bookingId: bookingId,
                to: .cancelled,
                actor: .caregiver,
                callerUid: caregiverUid
            )
            if let index = appointments.firstIndex(where: { $0.id == bookingId }) {
                appointments[index] = updated
            }
            categorizeAppointments()
            riskByBookingId.removeValue(forKey: bookingId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startBookingVisit(bookingId: String, caregiverUid: String, firestoreService: FirestoreService) async {
        do {
            let updated = try await firestoreService.applyBookingTransition(
                bookingId: bookingId,
                to: .inProgress,
                actor: .caregiver,
                callerUid: caregiverUid
            )
            if let index = appointments.firstIndex(where: { $0.id == bookingId }) {
                appointments[index] = updated
            }
            categorizeAppointments()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func completeBooking(bookingId: String, caregiverUid: String, firestoreService: FirestoreService) async {
        do {
            let updated = try await firestoreService.applyBookingTransition(
                bookingId: bookingId,
                to: .completed,
                actor: .caregiver,
                callerUid: caregiverUid
            )
            if let index = appointments.firstIndex(where: { $0.id == bookingId }) {
                appointments[index] = updated
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
