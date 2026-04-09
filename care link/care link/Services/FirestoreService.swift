import Foundation
import FirebaseFirestore

@Observable
final class FirestoreService {
    private var db: Firestore { Firestore.firestore() }

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

    // MARK: - Medical Records

    func addMedicalRecord(_ record: MedicalRecord) async throws {
        try await encodeAndSet(record, at: db.collection("medicalRecords").document(record.id))
    }

    func fetchMedicalRecordsForPatient(_ patientId: String) async throws -> [MedicalRecord] {
        let snapshot = try await db.collection("medicalRecords")
            .whereField("patientId", isEqualTo: patientId)
            .order(by: "date", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            try? doc.data(as: MedicalRecord.self)
        }
    }

    func fetchMedicalRecordsByCaregiver(_ caregiverId: String, patientId: String) async throws -> [MedicalRecord] {
        let snapshot = try await db.collection("medicalRecords")
            .whereField("caregiverId", isEqualTo: caregiverId)
            .whereField("patientId", isEqualTo: patientId)
            .order(by: "date", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            try? doc.data(as: MedicalRecord.self)
        }
    }

    // MARK: - Family Members

    func addFamilyMember(_ member: FamilyMember) async throws {
        try await encodeAndSet(member, at: db.collection("familyMembers").document(member.id))
    }

    func fetchFamilyMembers(for ownerUserId: String) async throws -> [FamilyMember] {
        let snapshot = try await db.collection("familyMembers")
            .whereField("ownerUserId", isEqualTo: ownerUserId)
            .order(by: "createdAt", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            try? doc.data(as: FamilyMember.self)
        }
    }

    func updateFamilyMember(_ member: FamilyMember) async throws {
        try await encodeAndSet(member, at: db.collection("familyMembers").document(member.id), merge: true)
    }

    func deleteFamilyMember(memberId: String) async throws {
        try await db.collection("familyMembers").document(memberId).delete()
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
