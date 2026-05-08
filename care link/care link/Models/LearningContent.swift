// File responsibility: Defines learning content logic for the care link app.

import Foundation

enum LearningContentCategory: String, CaseIterable, Identifiable, Codable, Hashable {
    case gettingStarted
    case booking
    case family
    case caregiverPortal
    case safety
    case platformTips

    var id: String { rawValue }

    var title: String {
        // Handle each state transition explicitly.
        switch self {
        case .gettingStarted: return "Getting Started"
        case .booking: return "Booking"
        case .family: return "Family & Care Circle"
        case .caregiverPortal: return "Caregiver Portal"
        case .safety: return "Safety & Privacy"
        case .platformTips: return "Platform Tips"
        }
    }

    var symbol: String {
        // Handle each state transition explicitly.
        switch self {
        case .gettingStarted: return "sparkles"
        case .booking: return "calendar.badge.plus"
        case .family: return "person.3"
        case .caregiverPortal: return "briefcase.fill"
        case .safety: return "shield.checkered"
        case .platformTips: return "lightbulb.fill"
        }
    }

    var subtitle: String {
        switch self {
        case .gettingStarted: return "Learn the app flow in minutes"
        case .booking: return "Create and manage appointments"
        case .family: return "Coordinate care with relatives"
        case .caregiverPortal: return "Use the dashboard effectively"
        case .safety: return "Understand privacy and biometric lock"
        case .platformTips: return "Make the most of CareLink"
        }
    }
}

struct LearningArticleSection: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let body: [String]

    init(id: String = UUID().uuidString, title: String, body: [String]) {
        self.id = id
        self.title = title
        self.body = body
    }
}

struct LearningArticle: Identifiable, Codable, Hashable {
    let id: String
    let category: LearningContentCategory
    let title: String
    let summary: String
    let estimatedReadMinutes: Int
    let lastUpdated: Date
    let featured: Bool
    let tags: [String]
    let sections: [LearningArticleSection]

    init(
        id: String = UUID().uuidString,
        category: LearningContentCategory,
        title: String,
        summary: String,
        estimatedReadMinutes: Int,
        lastUpdated: Date,
        featured: Bool = false,
        tags: [String] = [],
        sections: [LearningArticleSection]
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.summary = summary
        self.estimatedReadMinutes = estimatedReadMinutes
        self.lastUpdated = lastUpdated
        self.featured = featured
        self.tags = tags
        self.sections = sections
    }
}