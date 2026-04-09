import Foundation

struct FamilyMember: Identifiable, Codable, Sendable {
    let id: String
    var ownerUserId: String
    var fullName: String
    var relation: String
    var dateOfBirth: Date
    var healthNotes: String
    var photoURL: String
    var createdAt: Date

    var age: Int {
        Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year ?? 0
    }
}
