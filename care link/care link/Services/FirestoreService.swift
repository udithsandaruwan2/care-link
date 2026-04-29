import Foundation
import FirebaseFirestore
import FirebaseAuth

struct CaregiverActivePatientSelection: Sendable {
    let patientId: String
    let patientName: String
    let updatedAt: Date
}

@Observable
final class FirestoreService {
    private var db: Firestore { Firestore.firestore() }
    private var userBookingsListener: ListenerRegistration?
    private var userNotificationsListener: ListenerRegistration?

    private func encodeAndSet<T: Encodable>(_ value: T, at ref: DocumentReference, merge: Bool = false) async throws {
        let data = try Firestore.Encoder().encode(value)
        if merge {
            try await ref.setData(data, merge: true)
        } else {
            try await ref.setData(data)
        }
    }

    // MARK: - Caregivers

    func fetchCaregivers() async throws -> [Caregiver] {
        let snapshot = try await db.collection("caregivers").getDocuments()
        return snapshot.documents.compactMap { doc in
            do {
                return try doc.data(as: Caregiver.self)
            } catch {
                print("Failed to decode caregiver \(doc.documentID): \(error)")
                return nil
            }
        }
    }

    func fetchCaregiver(id: String) async throws -> Caregiver? {
        let document = try await db.collection("caregivers").document(id).getDocument()
        return try? document.data(as: Caregiver.self)
    }

    func fetchCaregiverByUserId(_ userId: String) async throws -> Caregiver? {
        let snapshot = try await db.collection("caregivers")
            .whereField("userId", isEqualTo: userId)
            .limit(to: 1)
            .getDocuments()
        return snapshot.documents.first.flatMap { try? $0.data(as: Caregiver.self) }
    }

    func searchCaregivers(query: String, category: Caregiver.CareCategory?) async throws -> [Caregiver] {
        var caregivers = try await fetchCaregivers()

        if !query.isEmpty {
            caregivers = caregivers.filter {
                $0.name.localizedCaseInsensitiveContains(query) ||
                $0.specialty.localizedCaseInsensitiveContains(query)
            }
        }

        if let category, category != .all {
            caregivers = caregivers.filter { $0.category == category }
        }

        return caregivers
    }

    func createCaregiverProfile(_ caregiver: Caregiver) async throws {
        try await encodeAndSet(caregiver, at: db.collection("caregivers").document(caregiver.id))
    }

    func updateCaregiverProfile(_ caregiver: Caregiver) async throws {
        try await encodeAndSet(caregiver, at: db.collection("caregivers").document(caregiver.id), merge: true)
    }

    // MARK: - Bookings

    func createBooking(_ booking: Booking) async throws {
        try await encodeAndSet(booking, at: db.collection("bookings").document(booking.id))
    }

    func fetchBooking(bookingId: String) async throws -> Booking? {
        let document = try await db.collection("bookings").document(bookingId).getDocument()
        guard document.exists else { return nil }
        return try document.data(as: Booking.self)
    }

    func fetchBookings(for userId: String) async throws -> [Booking] {
        let snapshot = try await db.collection("bookings")
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            try? doc.data(as: Booking.self)
        }
    }

    // MARK: - Realtime Bookings

    func listenToBookingsForUser(
        _ userId: String,
        onUpdate: @escaping ([Booking]) -> Void
    ) {
        stopListeningToBookingsForUser()
        guard !userId.isEmpty else {
            onUpdate([])
            return
        }

        let baseQuery = db.collection("bookings").whereField("userId", isEqualTo: userId)
        userBookingsListener = baseQuery
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                if let snapshot {
                    let bookings = snapshot.documents.compactMap { try? $0.data(as: Booking.self) }
                    onUpdate(bookings)
                    return
                }
                // Avoid clearing UI state on transient/index errors; fallback to base query and local sorting.
                if error != nil {
                    self?.userBookingsListener?.remove()
                    self?.userBookingsListener = baseQuery.addSnapshotListener { fallbackSnapshot, _ in
                        guard let fallbackSnapshot else { return }
                        let bookings = fallbackSnapshot.documents.compactMap { try? $0.data(as: Booking.self) }
                            .sorted { $0.createdAt > $1.createdAt }
                        onUpdate(bookings)
                    }
                }
            }
    }

    func stopListeningToBookingsForUser() {
        userBookingsListener?.remove()
        userBookingsListener = nil
    }

    // MARK: - Notifications

    func createNotification(_ notification: CLNotification) async throws {
        let ref = db.collection("users")
            .document(notification.userId)
            .collection("notifications")
            .document(notification.id)
        try await encodeAndSet(notification, at: ref)
    }

    func listenToNotificationsForUser(
        _ userId: String,
        onUpdate: @escaping ([CLNotification]) -> Void
    ) {
        stopListeningToNotificationsForUser()
        guard !userId.isEmpty else {
            onUpdate([])
            return
        }

        userNotificationsListener = db.collection("users")
            .document(userId)
            .collection("notifications")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, _ in
                guard let snapshot else { return }
                let items = snapshot.documents.compactMap { try? $0.data(as: CLNotification.self) }
                onUpdate(items)
            }
    }

    func stopListeningToNotificationsForUser() {
        userNotificationsListener?.remove()
        userNotificationsListener = nil
    }

    func markNotificationRead(userId: String, notificationId: String) async throws {
        try await db.collection("users")
            .document(userId)
            .collection("notifications")
            .document(notificationId)
            .updateData(["isRead": true])
    }

    func markAllNotificationsRead(userId: String) async throws {
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("notifications")
            .whereField("isRead", isEqualTo: false)
            .getDocuments()

        let batch = db.batch()
        for doc in snapshot.documents {
            batch.updateData(["isRead": true], forDocument: doc.reference)
        }
        try await batch.commit()
    }

    func fetchCaregiverBookings(for caregiverId: String) async throws -> [Booking] {
        let snapshot = try await db.collection("bookings")
            .whereField("caregiverId", isEqualTo: caregiverId)
            .order(by: "createdAt", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            try? doc.data(as: Booking.self)
        }
    }

    func updateBookingStatus(bookingId: String, status: Booking.BookingStatus) async throws {
        try await db.collection("bookings").document(bookingId).updateData([
            "status": status.rawValue
        ])
    }

    func requestBookingCancellation(
        bookingId: String,
        requesterUid: String,
        requesterRole: BookingStateMachine.Actor
    ) async throws {
        guard let booking = try await fetchBooking(bookingId: bookingId) else { return }
        guard BookingStateMachine.callerMatches(actor: requesterRole, booking: booking, callerUid: requesterUid) else {
            throw BookingStateMachine.TransitionError.forbidden
        }
        guard BookingStateMachine.patientMayRequestCancel(status: booking.status) else { return }

        try await db.collection("bookings").document(bookingId).updateData([
            "cancellationRequestedByUid": requesterUid,
            "cancellationRequestedByRole": requesterRole == .patient ? "patient" : "caregiver",
            "cancellationRequestedAt": Timestamp(date: Date())
        ])
    }

    func clearBookingCancellationRequest(bookingId: String) async throws {
        try await db.collection("bookings").document(bookingId).updateData([
            "cancellationRequestedByUid": FieldValue.delete(),
            "cancellationRequestedByRole": FieldValue.delete(),
            "cancellationRequestedAt": FieldValue.delete()
        ])
    }

    /// Validates domain rules, updates status, and keeps `connections` aligned with booking outcomes.
    func applyBookingTransition(
        bookingId: String,
        to newStatus: Booking.BookingStatus,
        actor: BookingStateMachine.Actor,
        callerUid: String
    ) async throws -> Booking {
        guard let booking = try await fetchBooking(bookingId: bookingId) else {
            throw BookingStateMachine.TransitionError.bookingNotFound
        }
        guard BookingStateMachine.callerMatches(actor: actor, booking: booking, callerUid: callerUid) else {
            throw BookingStateMachine.TransitionError.forbidden
        }
        guard BookingStateMachine.canTransition(from: booking.status, to: newStatus, actor: actor) else {
            throw BookingStateMachine.TransitionError.invalidTransition(from: booking.status, to: newStatus, actor: actor)
        }

        try await updateBookingStatus(bookingId: bookingId, status: newStatus)
        if newStatus == .cancelled {
            try? await clearBookingCancellationRequest(bookingId: bookingId)
        }

        var updated = booking
        updated.status = newStatus
        if let connectionStatus = BookingStateMachine.connectionStatusAfterTransition(
            from: booking.status,
            to: newStatus,
            actor: actor
        ) {
            try await upsertConnectionForBooking(booking: updated, status: connectionStatus)
        }

        try? await createBookingTransitionNotifications(
            previous: booking,
            updated: updated,
            actor: actor,
            callerUid: callerUid
        )
        return updated
    }

    private func createBookingTransitionNotifications(
        previous: Booking,
        updated: Booking,
        actor: BookingStateMachine.Actor,
        callerUid: String
    ) async throws {
        let patientId = updated.userId
        let caregiverId = updated.caregiverId

        func make(
            to userId: String,
            title: String,
            message: String,
            type: CLNotification.NotificationType
        ) async throws {
            let note = CLNotification(
                id: UUID().uuidString,
                userId: userId,
                senderUserId: callerUid,
                title: title,
                message: message,
                type: type,
                isRead: false,
                createdAt: Date(),
                bookingId: updated.id
            )
            try await createNotification(note)
        }

        switch updated.status {
        case .confirmed:
            if actor == .caregiver {
                try await make(
                    to: patientId,
                    title: "Booking confirmed",
                    message: "\(updated.caregiverName) confirmed your booking.",
                    type: .bookingConfirmed
                )
                try await make(
                    to: patientId,
                    title: "Upcoming appointment reminder",
                    message: "Care visit with \(updated.caregiverName) is scheduled for \(updated.startTime.formatted(date: .omitted, time: .shortened)).",
                    type: .bookingReminder
                )
            }
        case .cancelled:
            let receiver = callerUid == patientId ? caregiverId : patientId
            let senderLabel = callerUid == patientId ? "Patient" : updated.caregiverName
            try await make(
                to: receiver,
                title: "Booking cancelled",
                message: "\(senderLabel) cancelled the booking request.",
                type: .bookingCancelled
            )
        case .inProgress:
            try await make(
                to: patientId,
                title: "Visit started",
                message: "\(updated.caregiverName) marked your booking as in progress.",
                type: .statusUpdate
            )
        case .completed:
            try await make(
                to: patientId,
                title: "Visit completed",
                message: "\(updated.caregiverName) marked your booking as completed.",
                type: .statusUpdate
            )
        case .awaitingCaregiver, .pending:
            break
        }
    }

    func deleteBooking(bookingId: String) async throws {
        try await db.collection("bookings").document(bookingId).delete()
    }

    // MARK: - Reviews

    func fetchReviews(for caregiverId: String) async throws -> [Review] {
        let snapshot = try await db.collection("reviews")
            .whereField("caregiverId", isEqualTo: caregiverId)
            .order(by: "createdAt", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            try? doc.data(as: Review.self)
        }
    }

    func addReview(_ review: Review) async throws {
        try await encodeAndSet(review, at: db.collection("reviews").document(review.id))
    }

    // MARK: - Connections

    func createConnection(_ connection: Connection) async throws {
        try await encodeAndSet(connection, at: db.collection("connections").document(connection.id))
    }

    func fetchConnectionsForUser(_ userId: String) async throws -> [Connection] {
        let snapshot = try await db.collection("connections")
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            try? doc.data(as: Connection.self)
        }
    }

    func fetchConnectionsForCaregiver(_ caregiverId: String) async throws -> [Connection] {
        let snapshot = try await db.collection("connections")
            .whereField("caregiverId", isEqualTo: caregiverId)
            .order(by: "createdAt", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            try? doc.data(as: Connection.self)
        }
    }

    func fetchActiveConnectionForUser(_ userId: String) async throws -> Connection? {
        let snapshot = try await db.collection("connections")
            .whereField("userId", isEqualTo: userId)
            .whereField("status", isEqualTo: Connection.ConnectionStatus.approved.rawValue)
            .limit(to: 1)
            .getDocuments()

        return snapshot.documents.first.flatMap { try? $0.data(as: Connection.self) }
    }

    func fetchActiveConnectionsForCaregiver(_ caregiverId: String) async throws -> [Connection] {
        let snapshot = try await db.collection("connections")
            .whereField("caregiverId", isEqualTo: caregiverId)
            .whereField("status", isEqualTo: Connection.ConnectionStatus.approved.rawValue)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            try? doc.data(as: Connection.self)
        }
    }

    func fetchPendingConnectionsForCaregiver(_ caregiverId: String) async throws -> [Connection] {
        let snapshot = try await db.collection("connections")
            .whereField("caregiverId", isEqualTo: caregiverId)
            .whereField("status", isEqualTo: Connection.ConnectionStatus.pending.rawValue)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            try? doc.data(as: Connection.self)
        }
    }

    func updateConnectionStatus(connectionId: String, status: Connection.ConnectionStatus) async throws {
        try await db.collection("connections").document(connectionId).updateData([
            "status": status.rawValue
        ])
    }

    func checkExistingConnection(userId: String, caregiverId: String) async throws -> Connection? {
        let snapshot = try await db.collection("connections")
            .whereField("userId", isEqualTo: userId)
            .whereField("caregiverId", isEqualTo: caregiverId)
            .limit(to: 1)
            .getDocuments()

        return snapshot.documents.first.flatMap { try? $0.data(as: Connection.self) }
    }

    func upsertConnectionForBooking(
        booking: Booking,
        status: Connection.ConnectionStatus
    ) async throws {
        if let existing = try await checkExistingConnection(userId: booking.userId, caregiverId: booking.caregiverId) {
            try await updateConnectionStatus(connectionId: existing.id, status: status)
            return
        }

        let newConnection = Connection(
            id: "conn_\(UUID().uuidString.prefix(10).lowercased())",
            userId: booking.userId,
            userName: booking.patientName.isEmpty ? "Patient" : booking.patientName,
            caregiverId: booking.caregiverId,
            caregiverName: booking.caregiverName,
            caregiverSpecialty: booking.caregiverSpecialty,
            status: status,
            createdAt: Date()
        )
        try await createConnection(newConnection)
    }

    // MARK: - Medical Records

    func addMedicalRecord(_ record: MedicalRecord) async throws {
        try await encodeAndSet(record, at: db.collection("medicalRecords").document(record.id))
    }

    func fetchMedicalRecordsForPatient(_ patientId: String) async throws -> [MedicalRecord] {
        let baseQuery = db.collection("medicalRecords")
            .whereField("patientId", isEqualTo: patientId)
        do {
            let snapshot = try await baseQuery
                .order(by: "date", descending: true)
                .getDocuments()
            return snapshot.documents.compactMap { try? $0.data(as: MedicalRecord.self) }
        } catch {
            let fallback = try await baseQuery.getDocuments()
            return fallback.documents
                .compactMap { try? $0.data(as: MedicalRecord.self) }
                .sorted { $0.date > $1.date }
        }
    }

    func fetchMedicalRecordsByCaregiver(_ caregiverId: String, patientId: String) async throws -> [MedicalRecord] {
        let baseQuery = db.collection("medicalRecords")
            .whereField("caregiverId", isEqualTo: caregiverId)
            .whereField("patientId", isEqualTo: patientId)
        do {
            let snapshot = try await baseQuery
                .order(by: "date", descending: true)
                .getDocuments()
            return snapshot.documents.compactMap { try? $0.data(as: MedicalRecord.self) }
        } catch {
            let fallback = try await baseQuery.getDocuments()
            return fallback.documents
                .compactMap { try? $0.data(as: MedicalRecord.self) }
                .sorted { $0.date > $1.date }
        }
    }

    /// Caregiver-facing patient chart should show all records for that patient, not only records created by current caregiver.
    func fetchMedicalRecordsForCaregiverPatient(_ patientId: String) async throws -> [MedicalRecord] {
        try await fetchMedicalRecordsForPatient(patientId)
    }

    // MARK: - Family Members

    func addFamilyMember(_ member: FamilyMember) async throws {
        let currentUid = Auth.auth().currentUser?.uid ?? ""
        guard !currentUid.isEmpty else {
            throw NSError(domain: "FirestoreService", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Your session expired. Please sign in again."
            ])
        }

        // Enforce owner id from the authenticated user to satisfy Firestore rules.
        var normalized = member
        normalized.ownerUserId = currentUid
        do {
            try await encodeAndSet(normalized, at: db.collection("familyMembers").document(normalized.id))
        } catch {
            // Fallback path for projects where top-level familyMembers rules are not yet deployed.
            try await appendFamilyMemberToUserDocument(normalized, userId: currentUid)
        }
    }

    func fetchFamilyMembers(for ownerUserId: String) async throws -> [FamilyMember] {
        do {
            let snapshot = try await db.collection("familyMembers")
                .whereField("ownerUserId", isEqualTo: ownerUserId)
                .order(by: "createdAt", descending: true)
                .getDocuments()

            return snapshot.documents.compactMap { doc in
                try? doc.data(as: FamilyMember.self)
            }
        } catch {
            return try await fetchFamilyMembersFromUserDocument(userId: ownerUserId)
        }
    }

    func updateFamilyMember(_ member: FamilyMember) async throws {
        try await encodeAndSet(member, at: db.collection("familyMembers").document(member.id), merge: true)
    }

    func deleteFamilyMember(memberId: String) async throws {
        try await db.collection("familyMembers").document(memberId).delete()
    }

    private func appendFamilyMemberToUserDocument(_ member: FamilyMember, userId: String) async throws {
        let payload: [String: Any] = [
            "id": member.id,
            "ownerUserId": member.ownerUserId,
            "fullName": member.fullName,
            "relation": member.relation,
            "dateOfBirth": Timestamp(date: member.dateOfBirth),
            "healthNotes": member.healthNotes,
            "photoURL": member.photoURL,
            "createdAt": Timestamp(date: member.createdAt)
        ]
        try await db.collection("users").document(userId).setData([
            "familyMembers": FieldValue.arrayUnion([payload])
        ], merge: true)
    }

    private func fetchFamilyMembersFromUserDocument(userId: String) async throws -> [FamilyMember] {
        let snapshot = try await db.collection("users").document(userId).getDocument()
        guard let raw = snapshot.data()?["familyMembers"] as? [[String: Any]] else { return [] }
        return raw.compactMap { item in
            guard let id = item["id"] as? String else { return nil }
            let fullName = item["fullName"] as? String ?? ""
            let relation = item["relation"] as? String ?? "Other"
            let dob = (item["dateOfBirth"] as? Timestamp)?.dateValue() ?? Date()
            let notes = item["healthNotes"] as? String ?? ""
            let photoURL = item["photoURL"] as? String ?? ""
            let created = (item["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            return FamilyMember(
                id: id,
                ownerUserId: userId,
                fullName: fullName,
                relation: relation,
                dateOfBirth: dob,
                healthNotes: notes,
                photoURL: photoURL,
                createdAt: created
            )
        }
        .sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Users

    func fetchUser(_ userId: String) async throws -> CLUser? {
        let document = try await db.collection("users").document(userId).getDocument()
        return try? document.data(as: CLUser.self)
    }

    func createUser(_ user: CLUser) async throws {
        try await encodeAndSet(user, at: db.collection("users").document(user.id))
    }

    func updateUser(_ user: CLUser) async throws {
        try await encodeAndSet(user, at: db.collection("users").document(user.id), merge: true)
    }

    // MARK: - Caregiver Active Patient

    /// Persists a single active patient for the caregiver on their user document.
    func setActivePatientForCaregiver(
        caregiverId: String,
        patientId: String,
        patientName: String
    ) async throws {
        try await db.collection("users").document(caregiverId).updateData([
            "activePatientId": patientId,
            "activePatientName": patientName,
            "activePatientUpdatedAt": Timestamp(date: Date())
        ])
    }

    func clearActivePatientForCaregiver(caregiverId: String) async throws {
        try await db.collection("users").document(caregiverId).updateData([
            "activePatientId": FieldValue.delete(),
            "activePatientName": FieldValue.delete(),
            "activePatientUpdatedAt": FieldValue.delete()
        ])
    }

    func fetchActivePatientForCaregiver(caregiverId: String) async throws -> CaregiverActivePatientSelection? {
        let snapshot = try await db.collection("users").document(caregiverId).getDocument()
        guard let data = snapshot.data(),
              let patientId = data["activePatientId"] as? String,
              !patientId.isEmpty else {
            return nil
        }

        let patientName = (data["activePatientName"] as? String) ?? "Patient"
        let updatedAt: Date
        if let ts = data["activePatientUpdatedAt"] as? Timestamp {
            updatedAt = ts.dateValue()
        } else {
            updatedAt = Date()
        }
        return CaregiverActivePatientSelection(
            patientId: patientId,
            patientName: patientName,
            updatedAt: updatedAt
        )
    }

    // MARK: - Connected Patients (for caregivers)

    func fetchConnectedPatients(caregiverId: String) async throws -> [CLUser] {
        let connections = try await fetchActiveConnectionsForCaregiver(caregiverId)
        var patients: [CLUser] = []
        for connection in connections {
            if let user = try await fetchUser(connection.userId) {
                patients.append(user)
            }
        }
        return patients
    }
}
