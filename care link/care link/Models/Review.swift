// File responsibility: Defines review logic for the care link app.

import Foundation

struct Review: Identifiable, Codable, Sendable {
    let id: String
    var caregiverId: String
    var userId: String
    var userName: String
    var rating: Double
    var comment: String
    var createdAt: Date
}
