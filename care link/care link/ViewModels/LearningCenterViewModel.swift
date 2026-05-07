import SwiftUI

@Observable
final class LearningCenterViewModel {
    private let repository: any LearningContentProviding

    var searchText = ""
    var selectedCategory: LearningContentCategory? = nil

    init(repository: any LearningContentProviding = LearningContentRepository()) {
        self.repository = repository
    }

    var featuredArticles: [LearningArticle] {
        repository.featuredArticles()
    }

    var filteredArticles: [LearningArticle] {
        repository.search(query: searchText, category: selectedCategory)
    }

    func relatedArticles(to article: LearningArticle) -> [LearningArticle] {
        repository.relatedArticles(to: article)
    }
}