import Foundation

struct Caregiver: Identifiable, Codable, Sendable, Hashable {
    let id: String
    var userId: String
    var name: String
    var specialty: String
    var title: String
    var hourlyRate: Double
    var rating: Double
    var reviewCount: Int
    var experienceYears: Int
    var distance: Double
    var bio: String
    var skills: [String]
    var education: [String]
    var certifications: [String]
    var availability: [String]
    var imageURL: String
    var latitude: Double
    var longitude: Double
    var isVerified: Bool
    var category: CareCategory
    var phoneNumber: String
    var email: String

    enum CareCategory: String, Codable, Sendable, CaseIterable {
        case all = "All"
        case elderly = "Elderly"
        case child = "Child"
        case homeAssistance = "Home Assistance"
        case physicalTherapy = "Physical Therapy"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Caregiver, rhs: Caregiver) -> Bool {
        lhs.id == rhs.id
    }

    init(
        id: String,
        userId: String,
        name: String,
        specialty: String,
        title: String,
        hourlyRate: Double,
        rating: Double,
        reviewCount: Int,
        experienceYears: Int,
        distance: Double,
        bio: String,
        skills: [String],
        education: [String] = [],
        certifications: [String],
        availability: [String],
        imageURL: String,
        latitude: Double,
        longitude: Double,
        isVerified: Bool,
        category: CareCategory,
        phoneNumber: String,
        email: String
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.specialty = specialty
        self.title = title
        self.hourlyRate = hourlyRate
        self.rating = rating
        self.reviewCount = reviewCount
        self.experienceYears = experienceYears
        self.distance = distance
        self.bio = bio
        self.skills = skills
        self.education = education
        self.certifications = certifications
        self.availability = availability
        self.imageURL = imageURL
        self.latitude = latitude
        self.longitude = longitude
        self.isVerified = isVerified
        self.category = category
        self.phoneNumber = phoneNumber
        self.email = email
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decodeIfPresent(String.self, forKey: .userId) ?? ""
        name = try container.decode(String.self, forKey: .name)
        specialty = try container.decode(String.self, forKey: .specialty)
        title = try container.decode(String.self, forKey: .title)
        hourlyRate = try container.decode(Double.self, forKey: .hourlyRate)
        rating = try container.decodeIfPresent(Double.self, forKey: .rating) ?? 0
        reviewCount = try container.decodeIfPresent(Int.self, forKey: .reviewCount) ?? 0
        experienceYears = try container.decodeIfPresent(Int.self, forKey: .experienceYears) ?? 0
        distance = try container.decodeIfPresent(Double.self, forKey: .distance) ?? 0
        bio = try container.decodeIfPresent(String.self, forKey: .bio) ?? ""
        skills = try container.decodeIfPresent([String].self, forKey: .skills) ?? []
        education = try container.decodeIfPresent([String].self, forKey: .education) ?? []
        certifications = try container.decodeIfPresent([String].self, forKey: .certifications) ?? []
        availability = try container.decodeIfPresent([String].self, forKey: .availability) ?? []
        imageURL = try container.decodeIfPresent(String.self, forKey: .imageURL) ?? ""
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude) ?? 0
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude) ?? 0
        isVerified = try container.decodeIfPresent(Bool.self, forKey: .isVerified) ?? false
        category = try container.decodeIfPresent(CareCategory.self, forKey: .category) ?? .all
        phoneNumber = try container.decodeIfPresent(String.self, forKey: .phoneNumber) ?? ""
        email = try container.decodeIfPresent(String.self, forKey: .email) ?? ""
    }
}
