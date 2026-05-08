import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseFunctions

struct CaregiverActivePatientSelection: Sendable {
    let patientId: String
    let patientName: String
    let updatedAt: Date
}

@Observable
final class FirestoreService {
    private var db: Firestore { Firestore.firestore() }
    private var userBookingsListener: ListenerRegistration?
    private var userNotificationsListeners: [ListenerRegistration] = []
    private func isFunctionUnavailableError(_ error: Error) -> Bool {
        if error is BookingFunctionsError { return true }
        let ns = error as NSError
        let looksLikeNotFoundCode = ns.code == FunctionsErrorCode.notFound.rawValue || ns.code == 5
        if looksLikeNotFoundCode { return true }
        if let message = ns.userInfo[NSLocalizedDescriptionKey] as? String,
           message.localizedCaseInsensitiveContains("not found") {
            return true
        }
        return false
    }

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
        do {
            try await BookingFunctionsService.createBookingRequest(booking)
        } catch {
            guard isFunctionUnavailableError(error) else { throw error }
            // Dev fallback: preserve the server invariant (one blocking booking per patient).
            let existing = try await db.collection("bookings")
                .whereField("userId", isEqualTo: booking.userId)
                .whereField("status", in: Booking.BookingStatus.allCases.filter(\.blocksNewBookingRequest).map(\.rawValue))
                .limit(to: 1)
                .getDocuments()
            guard existing.documents.isEmpty else {
                throw NSError(
                    domain: "BookingFunctionsFallback",
                    code: 412,
                    userInfo: [NSLocalizedDescriptionKey: "You already have an active booking request."]
                )
            }
            // Keep booking flow usable if callable is not deployed yet.
            try await encodeAndSet(booking, at: db.collection("bookings").document(booking.id))
        }
    }

    func fetchBooking(bookingId: String) async throws -> Booking? {
        let document = try await db.collection("bookings").document(bookingId).getDocument()
        guard document.exists else { return nil }
        return try document.data(as: Booking.self)
    }

    func fetchBookings(for userId: String) async throws -> [Booking] {
        let baseQuery = db.collection("bookings")
            .whereField("userId", isEqualTo: userId)
        do {
            let snapshot = try await baseQuery
                .order(by: "createdAt", descending: true)
                .getDocuments()
            return snapshot.documents.compactMap { doc in
                try? doc.data(as: Booking.self)
            }
        } catch {
            // Fallback for projects missing the composite index required by ordered query.
            let snapshot = try await baseQuery.getDocuments()
            return snapshot.documents
                .compactMap { try? $0.data(as: Booking.self) }
                .sorted { $0.createdAt > $1.createdAt }
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

        Task {
            let ids = (try? await caregiverIdentifiers(for: userId)) ?? [userId]
            let syncQueue = DispatchQueue(label: "carelink.notifications.sync")
            var bucketByUser: [String: [CLNotification]] = [:]

            for id in ids {
                let listener = db.collection("users")
                    .document(id)
                    .collection("notifications")
                    .order(by: "createdAt", descending: true)
                    .addSnapshotListener { snapshot, _ in
                        let items = snapshot?.documents.compactMap { try? $0.data(as: CLNotification.self) } ?? []
                        syncQueue.sync {
                            bucketByUser[id] = items
                            let merged = bucketByUser.values
                                .flatMap { $0 }
                                .reduce(into: [String: CLNotification]()) { partial, item in
                                    partial[item.id] = item
                                }
                                .values
                                .sorted { $0.createdAt > $1.createdAt }
                            onUpdate(merged)
                        }
                    }
                userNotificationsListeners.append(listener)
            }
        }
    }

    func stopListeningToNotificationsForUser() {
        userNotificationsListeners.forEach { $0.remove() }
        userNotificationsListeners.removeAll()
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
        let identifiers = try await caregiverIdentifiers(for: caregiverId)
        var mergedById: [String: Booking] = [:]
        var caregiverNames: Set<String> = []
        if let caregiverProfile = try? await fetchCaregiverByUserId(caregiverId),
           !caregiverProfile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            caregiverNames.insert(caregiverProfile.name.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if let profile = try? await fetchUser(caregiverId),
           !profile.fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            caregiverNames.insert(profile.fullName.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        for identifier in identifiers {
            // Prefer indexed query path first.
            if let snapshot = try? await db.collection("bookings")
                .whereField("caregiverId", isEqualTo: identifier)
                .order(by: "createdAt", descending: true)
                .getDocuments() {
                for document in snapshot.documents {
                    if let booking = try? document.data(as: Booking.self) {
                        mergedById[booking.id] = booking
                    }
                }
                continue
            }

            // Fallback when the indexed query fails (e.g. missing composite index).
            if let snapshot = try? await db.collection("bookings")
                .whereField("caregiverId", isEqualTo: identifier)
                .getDocuments() {
                for document in snapshot.documents {
                    if let booking = try? document.data(as: Booking.self) {
                        mergedById[booking.id] = booking
                    }
                }
            }
        }
        if mergedById.isEmpty {
            for name in caregiverNames {
                if let nameSnapshot = try? await db.collection("bookings")
                    .whereField("caregiverName", isEqualTo: name)
                    .order(by: "createdAt", descending: true)
                    .getDocuments() {
                    for document in nameSnapshot.documents {
                        if let booking = try? document.data(as: Booking.self) {
                            mergedById[booking.id] = booking
                        }
                    }
                    continue
                }
                if let nameSnapshot = try? await db.collection("bookings")
                    .whereField("caregiverName", isEqualTo: name)
                    .getDocuments() {
                    for document in nameSnapshot.documents {
                        if let booking = try? document.data(as: Booking.self) {
                            mergedById[booking.id] = booking
                        }
                    }
                }
            }
        }
        let normalizedNames = Set(caregiverNames.map { CaregiverIdentityMatcher.normalizedName($0) })
        if mergedById.isEmpty {
            // Final fallback for inconsistent legacy docs: fetch all and filter in memory.
            let allSnapshot = try await db.collection("bookings").getDocuments()
            for document in allSnapshot.documents {
                guard let booking = try? document.data(as: Booking.self) else { continue }
                if CaregiverIdentityMatcher.matches(
                    caregiverId: booking.caregiverId,
                    caregiverName: booking.caregiverName,
                    knownIds: Set(identifiers),
                    knownNames: normalizedNames
                ) {
                    mergedById[booking.id] = booking
                }
            }
        }
        return mergedById.values.sorted { $0.createdAt > $1.createdAt }
    }

    func updateBookingStatus(bookingId: String, status: Booking.BookingStatus) async throws {
        do {
            try await BookingFunctionsService.updateBookingStatus(bookingId: bookingId, newStatus: status)
        } catch {
            guard isFunctionUnavailableError(error) else { throw error }
            // Dev fallback: keep caregiver/patient transitions usable before functions deploy.
            try await db.collection("bookings").document(bookingId).updateData([
                "status": status.rawValue
            ])
        }
    }

    func requestBookingCancellation(
        bookingId: String,
        requesterUid: String,
        requesterRole: BookingStateMachine.Actor
    ) async throws {
        guard let booking = try await fetchBooking(bookingId: bookingId) else { return }
        if requesterRole == .caregiver {
            guard try await caregiverCallerMatchesBooking(callerUid: requesterUid, booking: booking) else {
                throw BookingStateMachine.TransitionError.forbidden
            }
        } else {
            guard BookingStateMachine.callerMatches(actor: requesterRole, booking: booking, callerUid: requesterUid) else {
                throw BookingStateMachine.TransitionError.forbidden
            }
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
        if actor == .caregiver {
            guard try await caregiverCallerMatchesBooking(callerUid: callerUid, booking: booking) else {
                throw BookingStateMachine.TransitionError.forbidden
            }
        } else {
            guard BookingStateMachine.callerMatches(actor: actor, booking: booking, callerUid: callerUid) else {
                throw BookingStateMachine.TransitionError.forbidden
            }
        }
        guard BookingStateMachine.canTransition(from: booking.status, to: newStatus, actor: actor) else {
            throw BookingStateMachine.TransitionError.invalidTransition(from: booking.status, to: newStatus, actor: actor)
        }

        try await updateBookingStatus(bookingId: bookingId, status: newStatus)
        if newStatus == .cancelled {
            try? await clearBookingCancellationRequest(bookingId: bookingId)
        }

        guard let refreshed = try await fetchBooking(bookingId: bookingId) else {
            throw BookingStateMachine.TransitionError.bookingNotFound
        }

        if let connectionStatus = BookingStateMachine.connectionStatusAfterTransition(
            from: booking.status,
            to: refreshed.status,
            actor: actor
        ) {
            try? await upsertConnectionForBooking(booking: refreshed, status: connectionStatus)
        }

        try await createBookingTransitionNotifications(
            previous: booking,
            updated: refreshed,
            actor: actor,
            callerUid: callerUid
        )
        // If the booking reached a terminal state, and the caregiver's active
        // patient selection matches this booking's patient, clear it so the
        // caregiver home returns to a clean state.
        if refreshed.status == .cancelled || refreshed.status == .completed {
            let bookingPatientId = refreshed.careRecipientId ?? refreshed.userId
            if !bookingPatientId.isEmpty {
                if let active = try? await fetchActivePatientForCaregiver(caregiverId: refreshed.caregiverId),
                   active.patientId == bookingPatientId {
                    try? await clearActivePatientForCaregiver(caregiverId: refreshed.caregiverId)
                }
            }
        }

        return refreshed
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
            if case .caregiver = actor {
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
        try await fetchConnectionsForCaregiverIdentifiers(caregiverId: caregiverId) { query in
            try await query.order(by: "createdAt", descending: true).getDocuments()
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
        try await fetchConnectionsForCaregiverIdentifiers(caregiverId: caregiverId) { query in
            try await query
                .whereField("status", isEqualTo: Connection.ConnectionStatus.approved.rawValue)
                .getDocuments()
        }
    }

    func fetchPendingConnectionsForCaregiver(_ caregiverId: String) async throws -> [Connection] {
        try await fetchConnectionsForCaregiverIdentifiers(caregiverId: caregiverId) { query in
            try await query
                .whereField("status", isEqualTo: Connection.ConnectionStatus.pending.rawValue)
                .getDocuments()
        }
    }

    func updateConnectionStatus(connectionId: String, status: Connection.ConnectionStatus) async throws {
        try await db.collection("connections").document(connectionId).updateData([
            "status": status.rawValue
        ])
    }

    func checkExistingConnection(userId: String, caregiverId: String) async throws -> Connection? {
        let identifiers = try await caregiverIdentifiers(for: caregiverId)
        for identifier in identifiers {
            let snapshot = try await db.collection("connections")
                .whereField("userId", isEqualTo: userId)
                .whereField("caregiverId", isEqualTo: identifier)
                .limit(to: 1)
                .getDocuments()
            if let decoded = snapshot.documents.first.flatMap({ try? $0.data(as: Connection.self) }) {
                return decoded
            }
        }
        return nil
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
        do {
            return try await fetchMedicalRecordsForPatient(patientId)
        } catch {
            // Rules fallback: if patient-wide read is restricted, at least return
            // records authored by the signed-in caregiver for this patient.
            guard let caregiverUid = Auth.auth().currentUser?.uid, !caregiverUid.isEmpty else {
                throw error
            }
            let baseQuery = db.collection("medicalRecords")
                .whereField("patientId", isEqualTo: patientId)
                .whereField("caregiverId", isEqualTo: caregiverUid)
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

    private func fetchConnectionsForCaregiverIdentifiers(
        caregiverId: String,
        queryBuilder: @escaping (Query) async throws -> QuerySnapshot
    ) async throws -> [Connection] {
        let identifiers = try await caregiverIdentifiers(for: caregiverId)
        var caregiverNames: Set<String> = []
        if let caregiverProfile = try? await fetchCaregiverByUserId(caregiverId),
           !caregiverProfile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            caregiverNames.insert(caregiverProfile.name.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if let profile = try? await fetchUser(caregiverId),
           !profile.fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            caregiverNames.insert(profile.fullName.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        let normalizedNames = Set(caregiverNames.map { CaregiverIdentityMatcher.normalizedName($0) })
        let knownIds = Set(identifiers)

        var mergedById: [String: Connection] = [:]
        for identifier in identifiers {
            let query = db.collection("connections").whereField("caregiverId", isEqualTo: identifier)
            let snapshot = try await queryBuilder(query)
            for document in snapshot.documents {
                if let decoded = try? document.data(as: Connection.self) {
                    mergedById[decoded.id] = decoded
                }
            }
        }

        if mergedById.isEmpty {
            for name in caregiverNames {
                let snapshot = try await queryBuilder(
                    db.collection("connections").whereField("caregiverName", isEqualTo: name)
                )
                for document in snapshot.documents {
                    if let decoded = try? document.data(as: Connection.self) {
                        mergedById[decoded.id] = decoded
                    }
                }
            }
        }
        if mergedById.isEmpty {
            // Final fallback for inconsistent legacy docs: fetch all and filter in memory.
            let allSnapshot = try await db.collection("connections").getDocuments()
            for document in allSnapshot.documents {
                guard let connection = try? document.data(as: Connection.self) else { continue }
                if CaregiverIdentityMatcher.matches(
                    caregiverId: connection.caregiverId,
                    caregiverName: connection.caregiverName,
                    knownIds: knownIds,
                    knownNames: normalizedNames
                ) {
                    mergedById[connection.id] = connection
                }
            }
        }

        return mergedById.values.sorted { $0.createdAt > $1.createdAt }
    }

    private func caregiverIdentifiers(for caregiverId: String) async throws -> [String] {
        var identifiers: [String] = [caregiverId]
        if let caregiverProfile = try? await fetchCaregiverByUserId(caregiverId),
           !caregiverProfile.id.isEmpty,
           caregiverProfile.id != caregiverId {
            identifiers.append(caregiverProfile.id)
        }
        return Array(Set(identifiers))
    }

    private func caregiverCallerMatchesBooking(callerUid: String, booking: Booking) async throws -> Bool {
        if booking.caregiverId == callerUid {
            return true
        }
        if let caregiverProfile = try? await fetchCaregiverByUserId(callerUid) {
            return caregiverProfile.id == booking.caregiverId || caregiverProfile.userId == booking.caregiverId
        }
        return false
    }
}
