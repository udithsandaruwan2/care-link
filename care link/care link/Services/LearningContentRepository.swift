// File responsibility: Defines learning content repository logic for the care link app.

import Foundation

protocol LearningContentProviding {
    var articles: [LearningArticle] { get }
    func article(id: String) -> LearningArticle?
    func featuredArticles() -> [LearningArticle]
    func articles(for category: LearningContentCategory?) -> [LearningArticle]
    func search(query: String, category: LearningContentCategory?) -> [LearningArticle]
    func relatedArticles(to article: LearningArticle, limit: Int) -> [LearningArticle]
}

extension LearningContentProviding {
    func relatedArticles(to article: LearningArticle) -> [LearningArticle] {
        relatedArticles(to: article, limit: 3)
    }
}

final class LearningContentRepository: LearningContentProviding {
    let articles: [LearningArticle] = [
        LearningArticle(
            category: .gettingStarted,
            title: "Start with your home dashboard",
            summary: "A quick tour of the main tabs and the flow from sign-in to booking.",
            estimatedReadMinutes: 2,
            lastUpdated: .now,
            featured: true,
            tags: ["welcome", "navigation"],
            sections: [
                LearningArticleSection(
                    title: "What you’ll see first",
                    body: [
                        "After onboarding, the app opens to the main dashboard. From there you can search caregivers, review alerts, and manage your profile.",
                        "The tab bar keeps Home, Chat, Map, Alerts, and Profile available without making you backtrack through nested screens."
                    ]
                ),
                LearningArticleSection(
                    title: "Where your important tasks live",
                    body: [
                        "Home is the discovery surface. Alerts collects booking and system updates. Profile gives access to account settings, medical records, and support.",
                        "If you use the caregiver portal, the same account switches into a work queue for appointment handling."
                    ]
                )
            ]
        ),
        LearningArticle(
            category: .booking,
            title: "Book a caregiver in a few steps",
            summary: "Choose a caregiver, set time and duration, and confirm the request.",
            estimatedReadMinutes: 3,
            lastUpdated: .now,
            featured: true,
            tags: ["booking", "appointments"],
            sections: [
                LearningArticleSection(
                    title: "Before you confirm",
                    body: [
                        "Review the caregiver profile, specialties, rating, and education to make sure the match fits your needs.",
                        "The booking screen shows date, time, duration, location, and payment method before anything is submitted."
                    ]
                ),
                LearningArticleSection(
                    title: "After booking",
                    body: [
                        "A booking request is created and a chat thread is opened so caregiver and patient can coordinate quickly.",
                        "You can also add the appointment to your calendar from the confirmation screen."
                    ]
                )
            ]
        ),
        LearningArticle(
            category: .family,
            title: "Coordinate care with family members",
            summary: "Keep relatives or trusted contacts connected to the care circle.",
            estimatedReadMinutes: 2,
            lastUpdated: .now,
            featured: false,
            tags: ["family", "care circle"],
            sections: [
                LearningArticleSection(
                    title: "Why it matters",
                    body: [
                        "Family members can help keep track of appointments, care notes, and support information.",
                        "The app stores these relationships so the care circle stays attached to the right patient profile."
                    ]
                ),
                LearningArticleSection(
                    title: "When to use it",
                    body: [
                        "Add family contacts when multiple people help manage the same care recipient.",
                        "It is especially useful for shared decision making and follow-up reminders."
                    ]
                )
            ]
        ),
        LearningArticle(
            category: .caregiverPortal,
            title: "Use the caregiver dashboard efficiently",
            summary: "Accept, start, and complete bookings from a single work queue.",
            estimatedReadMinutes: 3,
            lastUpdated: .now,
            featured: true,
            tags: ["caregiver", "portal"],
            sections: [
                LearningArticleSection(
                    title: "What the dashboard shows",
                    body: [
                        "The caregiver portal splits bookings into pending, upcoming, and completed sections so you can focus on the next action.",
                        "Risk indicators can highlight bookings that may need closer attention."
                    ]
                ),
                LearningArticleSection(
                    title: "How status updates work",
                    body: [
                        "Accepting, starting, completing, or cancelling a booking updates the booking state and keeps the related connection in sync.",
                        "Those transitions are validated on both the app and Cloud Functions side."
                    ]
                )
            ]
        ),
        LearningArticle(
            category: .safety,
            title: "Keep your account secure",
            summary: "Understand biometric login, sign-out, and privacy controls.",
            estimatedReadMinutes: 2,
            lastUpdated: .now,
            featured: false,
            tags: ["privacy", "biometrics"],
            sections: [
                LearningArticleSection(
                    title: "Biometric unlock",
                    body: [
                        "When biometric login is enabled in both the local app preference and your profile, CareLink can require Face ID or Touch ID after backgrounding or relaunch.",
                        "If biometrics stop being available, the app can remove the saved unlock preference so you do not get locked out."
                    ]
                ),
                LearningArticleSection(
                    title: "What stays local",
                    body: [
                        "Some session information is stored on-device in Core Data, UserDefaults, and Keychain to support offline and secure sign-in experiences.",
                        "You can clear local data from Settings if you need a fresh start on the device."
                    ]
                )
            ]
        ),
        LearningArticle(
            category: .platformTips,
            title: "Make the most of CareLink",
            summary: "A few habits that keep the experience smooth.",
            estimatedReadMinutes: 2,
            lastUpdated: .now,
            featured: false,
            tags: ["tips", "productivity"],
            sections: [
                LearningArticleSection(
                    title: "Use search and filters",
                    body: [
                        "Search by name or specialty to narrow the caregiver list quickly.",
                        "On Home and Map, filters help you focus on the options that best fit the care need."
                    ]
                ),
                LearningArticleSection(
                    title: "Check alerts regularly",
                    body: [
                        "Booking updates, reminders, and status changes can appear in Alerts and in the notification center.",
                        "Reviewing alerts keeps you from missing a caregiver response or a schedule change."
                    ]
                )
            ]
        )
    ]

    func article(id: String) -> LearningArticle? {
        articles.first { $0.id == id }
    }

    func featuredArticles() -> [LearningArticle] {
        articles.filter { $0.featured }
    }

    func articles(for category: LearningContentCategory?) -> [LearningArticle] {
        // Validate required values before continuing.
        guard let category else { return articles }
        return articles.filter { $0.category == category }
    }

    func search(query: String, category: LearningContentCategory?) -> [LearningArticle] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let scoped = articles(for: category)
        // Validate required values before continuing.
        guard !trimmed.isEmpty else { return scoped }

        let lowercased = trimmed.lowercased()
        return scoped.filter { article in
            article.title.lowercased().contains(lowercased)
                || article.summary.lowercased().contains(lowercased)
                || article.tags.contains(where: { $0.lowercased().contains(lowercased) })
                || article.sections.contains(where: { section in
                    section.title.lowercased().contains(lowercased)
                        || section.body.joined(separator: " ").lowercased().contains(lowercased)
                })
        }
    }

    func relatedArticles(to article: LearningArticle, limit: Int = 3) -> [LearningArticle] {
        articles
            .filter { $0.id != article.id }
            .filter { $0.category == article.category || !Set($0.tags).isDisjoint(with: Set(article.tags)) }
            .prefix(limit)
            .map { $0 }
    }
}