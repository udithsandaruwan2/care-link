import SwiftUI

@Observable
final class BookingViewModel {
    var selectedDate = Date()
    var startTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    var endTime = Calendar.current.date(bySettingHour: 13, minute: 0, second: 0, of: Date()) ?? Date()
    var selectedDuration: String? = "Morning (4h)"
    var selectedPaymentMethod: Booking.PaymentMethod = .cash
    var userBookings: [Booking] = []
    var isLoading = false
    var bookingConfirmed = false
    var confirmedBooking: Booking?
    var riskAssessment: BookingRiskAssessment?
    var errorMessage: String?
    var showError = false

    var duration: Double {
        max(endTime.timeIntervalSince(startTime) / 3600, 0.5)
    }

    func estimatedTotal(for caregiver: Caregiver) -> Double {
        caregiver.hourlyRate * duration
    }

    func selectPopularDuration(_ label: String) {
        selectedDuration = label
        let calendar = Calendar.current
        let baseStart = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: selectedDate) ?? selectedDate

        switch label {
        case "Morning (4h)":
            startTime = baseStart
            endTime = calendar.date(byAdding: .hour, value: 4, to: baseStart) ?? baseStart
        case "Afternoon (3h)":
            let afternoon = calendar.date(bySettingHour: 13, minute: 0, second: 0, of: selectedDate) ?? selectedDate
            startTime = afternoon
            endTime = calendar.date(byAdding: .hour, value: 3, to: afternoon) ?? afternoon
        case "Full Day (8h)":
            startTime = baseStart
            endTime = calendar.date(byAdding: .hour, value: 8, to: baseStart) ?? baseStart
        default:
            break
        }
    }

    func draftBooking(
        caregiver: Caregiver,
        userId: String,
        patientName: String,
        patientAddress: String
    ) -> Booking {
        let bookingId = "bk_\(UUID().uuidString.prefix(8).lowercased())"
        let addr = patientAddress.trimmingCharacters(in: .whitespaces)
        return Booking(
            id: bookingId,
            userId: userId,
            patientName: patientName,
            caregiverId: caregiver.id,
            caregiverName: caregiver.name,
            caregiverSpecialty: caregiver.specialty,
            caregiverImageURL: caregiver.imageURL,
            caregiverRating: caregiver.rating,
            date: selectedDate,
            startTime: startTime,
            endTime: endTime,
            duration: duration,
            totalCost: estimatedTotal(for: caregiver),
            status: .awaitingCaregiver,
            location: "Home Residence",
            address: addr.isEmpty ? "Address on file" : addr,
            paymentMethod: selectedPaymentMethod,
            createdAt: Date()
        )
    }

    func updateRiskAssessment(
        caregiver: Caregiver,
        userId: String,
        patientName: String,
        patientAddress: String,
        userHistory: [Booking],
        riskService: CoreMLBookingRiskService
    ) {
        let booking = draftBooking(
            caregiver: caregiver,
            userId: userId,
            patientName: patientName,
            patientAddress: patientAddress
        )
        riskAssessment = riskService.assessRisk(booking: booking, userHistory: userHistory)
    }

    func confirmBooking(
        caregiver: Caregiver,
        userId: String,
        patientName: String,
        patientAddress: String,
        firestoreService: FirestoreService,
        chatService: ChatService
    ) async -> Bool {
        isLoading = true
        defer { isLoading = false }

        if let existing = try? await firestoreService.fetchBookings(for: userId).first(where: { $0.status.blocksNewBookingRequest }) {
            let caregiverName = existing.caregiverName
            errorMessage = "You already have an active care request with \(caregiverName). Please complete or cancel it before booking another caregiver."
            showError = true
            return false
        }

        let booking = draftBooking(
            caregiver: caregiver,
            userId: userId,
            patientName: patientName,
            patientAddress: patientAddress
        )

        do {
            try await firestoreService.createBooking(booking)
            try? await firestoreService.upsertConnectionForBooking(
                booking: booking,
                status: .pending
            )
            try? await firestoreService.createNotification(
                CLNotification(
                    id: UUID().uuidString,
                    userId: caregiver.id,
                    senderUserId: userId,
                    title: "New booking request",
                    message: "\(patientName) requested care on \(booking.date.formatted(date: .abbreviated, time: .omitted)).",
                    type: .bookingRequest,
                    isRead: false,
                    createdAt: Date(),
                    bookingId: booking.id
                )
            )
            try? await firestoreService.createNotification(
                CLNotification(
                    id: UUID().uuidString,
                    userId: userId,
                    senderUserId: userId,
                    title: "Request sent",
                    message: "Your booking request to \(caregiver.name) was sent.",
                    type: .statusUpdate,
                    isRead: false,
                    createdAt: Date(),
                    bookingId: booking.id
                )
            )
            let conversation = try await chatService.getOrCreateConversation(
                userId: userId,
                userName: patientName,
                caregiverId: caregiver.id,
                caregiverName: caregiver.name,
                caregiverSpecialty: caregiver.specialty
            )
            try await chatService.sendBookingRequestMessage(
                conversationId: conversation.id,
                senderId: userId,
                senderName: patientName,
                booking: booking
            )
            confirmedBooking = booking
            bookingConfirmed = true
            return true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return false
        }
    }

    func loadUserBookings(userId: String, firestoreService: FirestoreService) async {
        do {
            userBookings = try await firestoreService.fetchBookings(for: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func cancelBooking(bookingId: String, patientUid: String, firestoreService: FirestoreService) async {
        do {
            let updated = try await firestoreService.applyBookingTransition(
                bookingId: bookingId,
                to: .cancelled,
                actor: .patient,
                callerUid: patientUid
            )
            if let index = userBookings.firstIndex(where: { $0.id == bookingId }) {
                userBookings[index] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
