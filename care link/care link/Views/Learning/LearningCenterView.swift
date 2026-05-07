import SwiftUI

struct LearningCenterView: View {
    @State private var viewModel = LearningCenterViewModel()

    private var hasSearchTerm: Bool {
        !viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CLTheme.spacingLG) {
                heroSection

                if !viewModel.featuredArticles.isEmpty {
                    featuredSection
                }

                categorySection

                articleSection
            }
            .padding(CLTheme.spacingMD)
            .padding(.bottom, 32)
        }
        .background(CLTheme.backgroundPrimary)
        .navigationTitle("Learning Center")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $viewModel.searchText, prompt: "Search lessons and tips")
    }

    private var heroSection: some View {
        CLCard {
            VStack(alignment: .leading, spacing: CLTheme.spacingMD) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: CLTheme.spacingSM) {
                        Text("Learn the app, faster")
                            .font(CLTheme.titleFont)
                            .foregroundStyle(CLTheme.textPrimary)

                        Text("Short guides that explain booking, safety, caregiver tools, and the overall CareLink flow.")
                            .font(CLTheme.bodyFont)
                            .foregroundStyle(CLTheme.textSecondary)
                    }

                    Spacer()

                    ZStack {
                        Circle()
                            .fill(CLTheme.gradientBlue)
                            .frame(width: 64, height: 64)
                        Image(systemName: "graduationcap.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }

                HStack(spacing: CLTheme.spacingSM) {
                    CLBadge(title: "Guided reading")
                    CLBadge(title: "Product tips", style: .outlined)
                }
            }
        }
    }

    private var featuredSection: some View {
        VStack(alignment: .leading, spacing: CLTheme.spacingMD) {
            Text("Featured")
                .font(CLTheme.title2Font)
                .foregroundStyle(CLTheme.textPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: CLTheme.spacingMD) {
                    ForEach(viewModel.featuredArticles) { article in
                        NavigationLink {
                            LearningArticleDetailView(article: article, viewModel: viewModel)
                        } label: {
                            featuredCard(article)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func featuredCard(_ article: LearningArticle) -> some View {
        VStack(alignment: .leading, spacing: CLTheme.spacingMD) {
            Image(systemName: article.category.symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(CLTheme.accentBlue)

            Text(article.title)
                .font(CLTheme.headlineFont)
                .foregroundStyle(CLTheme.textPrimary)
                .multilineTextAlignment(.leading)

            Text(article.summary)
                .font(CLTheme.captionFont)
                .foregroundStyle(CLTheme.textSecondary)
                .multilineTextAlignment(.leading)
                .lineLimit(3)

            Spacer(minLength: 0)

            HStack {
                Text("\(article.estimatedReadMinutes) min read")
                    .font(CLTheme.captionFont)
                    .foregroundStyle(CLTheme.textTertiary)
                Spacer()
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundStyle(CLTheme.accentBlue)
            }
        }
        .padding(CLTheme.spacingMD)
        .frame(width: 250, height: 180, alignment: .leading)
        .background(CLTheme.cardBackground)
        .clipShape(CLTheme.continuousRect(cornerRadius: CLTheme.cornerRadiusLG))
        .shadow(color: CLTheme.shadowLight, radius: 8, y: 2)
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: CLTheme.spacingMD) {
            Text("Browse by topic")
                .font(CLTheme.title2Font)
                .foregroundStyle(CLTheme.textPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: CLTheme.spacingSM) {
                    CLChip(title: "All", isSelected: viewModel.selectedCategory == nil) {
                        viewModel.selectedCategory = nil
                    }

                    ForEach(LearningContentCategory.allCases) { category in
                        CLChip(title: category.title, isSelected: viewModel.selectedCategory == category) {
                            viewModel.selectedCategory = category
                        }
                    }
                }
            }
        }
    }

    private var articleSection: some View {
        VStack(alignment: .leading, spacing: CLTheme.spacingMD) {
            HStack {
                Text(hasSearchTerm ? "Search results" : "All articles")
                    .font(CLTheme.title2Font)
                    .foregroundStyle(CLTheme.textPrimary)
                Spacer()
                Text("\(viewModel.filteredArticles.count)")
                    .font(CLTheme.captionFont)
                    .foregroundStyle(CLTheme.textTertiary)
            }

            if viewModel.filteredArticles.isEmpty {
                CLCard {
                    VStack(alignment: .leading, spacing: CLTheme.spacingSM) {
                        Text("No matching articles")
                            .font(CLTheme.headlineFont)
                            .foregroundStyle(CLTheme.textPrimary)
                        Text("Try another keyword or clear the topic filter.")
                            .font(CLTheme.bodyFont)
                            .foregroundStyle(CLTheme.textSecondary)
                    }
                }
            } else {
                LazyVStack(spacing: CLTheme.spacingMD) {
                    ForEach(viewModel.filteredArticles) { article in
                        NavigationLink {
                            LearningArticleDetailView(article: article, viewModel: viewModel)
                        } label: {
                            articleRow(article)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func articleRow(_ article: LearningArticle) -> some View {
        HStack(alignment: .top, spacing: CLTheme.spacingMD) {
            ZStack {
                RoundedRectangle(cornerRadius: CLTheme.cornerRadiusMD, style: .continuous)
                    .fill(CLTheme.lightBlue)
                    .frame(width: 52, height: 52)
                Image(systemName: article.category.symbol)
                    .foregroundStyle(CLTheme.primaryNavy)
            }

            VStack(alignment: .leading, spacing: CLTheme.spacingXS) {
                Text(article.category.title)
                    .font(CLTheme.captionFont)
                    .foregroundStyle(CLTheme.textTertiary)
                Text(article.title)
                    .font(CLTheme.headlineFont)
                    .foregroundStyle(CLTheme.textPrimary)
                Text(article.summary)
                    .font(CLTheme.bodyFont)
                    .foregroundStyle(CLTheme.textSecondary)
                    .lineLimit(2)
                HStack(spacing: CLTheme.spacingSM) {
                    Label("\(article.estimatedReadMinutes) min", systemImage: "clock")
                    Label(article.lastUpdated.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                }
                .font(CLTheme.captionFont)
                .foregroundStyle(CLTheme.textTertiary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(CLTheme.textTertiary)
                .padding(.top, 6)
        }
        .padding(CLTheme.spacingMD)
        .background(CLTheme.cardBackground)
        .clipShape(CLTheme.continuousRect(cornerRadius: CLTheme.cornerRadiusLG))
        .shadow(color: CLTheme.shadowLight, radius: 6, y: 2)
    }
}

struct LearningArticleDetailView: View {
    let article: LearningArticle
    let viewModel: LearningCenterViewModel

    private var relatedArticles: [LearningArticle] {
        viewModel.relatedArticles(to: article)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CLTheme.spacingLG) {
                headerCard

                ForEach(article.sections) { section in
                    sectionCard(section)
                }

                if !relatedArticles.isEmpty {
                    relatedSection
                }
            }
            .padding(CLTheme.spacingMD)
            .padding(.bottom, 24)
        }
        .background(CLTheme.backgroundPrimary)
        .navigationTitle(article.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerCard: some View {
        CLCard {
            VStack(alignment: .leading, spacing: CLTheme.spacingMD) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: CLTheme.spacingSM) {
                        Text(article.category.title)
                            .font(CLTheme.captionFont)
                            .foregroundStyle(CLTheme.textTertiary)

                        Text(article.title)
                            .font(CLTheme.titleFont)
                            .foregroundStyle(CLTheme.textPrimary)

                        Text(article.summary)
                            .font(CLTheme.bodyFont)
                            .foregroundStyle(CLTheme.textSecondary)
                    }

                    Spacer()

                    ZStack {
                        Circle()
                            .fill(CLTheme.gradientBlue)
                            .frame(width: 56, height: 56)
                        Image(systemName: article.category.symbol)
                            .foregroundStyle(.white)
                    }
                }

                HStack(spacing: CLTheme.spacingSM) {
                    CLBadge(title: "\(article.estimatedReadMinutes) min read")
                    CLBadge(title: article.lastUpdated.formatted(date: .abbreviated, time: .omitted), style: .outlined)
                }

                if !article.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: CLTheme.spacingSM) {
                            ForEach(article.tags, id: \.self) { tag in
                                CLBadge(title: tag.capitalized, style: .outlined)
                            }
                        }
                    }
                }
            }
        }
    }

    private func sectionCard(_ section: LearningArticleSection) -> some View {
        CLCard {
            VStack(alignment: .leading, spacing: CLTheme.spacingMD) {
                Text(section.title)
                    .font(CLTheme.title2Font)
                    .foregroundStyle(CLTheme.textPrimary)

                ForEach(section.body.indices, id: \.self) { index in
                    Text(section.body[index])
                        .font(CLTheme.bodyFont)
                        .foregroundStyle(CLTheme.textSecondary)
                }
            }
        }
    }

    private var relatedSection: some View {
        VStack(alignment: .leading, spacing: CLTheme.spacingMD) {
            Text("Related articles")
                .font(CLTheme.title2Font)
                .foregroundStyle(CLTheme.textPrimary)

            LazyVStack(spacing: CLTheme.spacingSM) {
                ForEach(relatedArticles) { item in
                    NavigationLink {
                        LearningArticleDetailView(article: item, viewModel: viewModel)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(CLTheme.headlineFont)
                                    .foregroundStyle(CLTheme.textPrimary)
                                Text(item.category.title)
                                    .font(CLTheme.captionFont)
                                    .foregroundStyle(CLTheme.textTertiary)
                            }
                            Spacer()
                            Image(systemName: "arrow.right")
                                .foregroundStyle(CLTheme.accentBlue)
                        }
                        .padding(CLTheme.spacingMD)
                        .background(CLTheme.cardBackground)
                        .clipShape(CLTheme.continuousRect(cornerRadius: CLTheme.cornerRadiusMD))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}