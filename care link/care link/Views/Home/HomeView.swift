import SwiftUI
import FirebaseAuth

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = HomeViewModel()
    @State private var selectedCaregiver: Caregiver?
    @State private var showCaregiverProfile = false
    @State private var navigationPath = NavigationPath()

    @State private var activeConnection: Connection?
    @State private var connectedCaregiver: Caregiver?
    @State private var showChat = false
    @State private var chatConversation: ChatConversation?

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                CLNavigationBar()

                ScrollView {
                    VStack(alignment: .leading, spacing: CLTheme.spacingMD) {
                        greetingSection
                        yourCaregiverCard
                        quickStatsRow

                        Text("Available Caregivers")
                            .font(CLTheme.title2Font)
                            .foregroundStyle(CLTheme.textPrimary)
                            .padding(.horizontal, CLTheme.spacingMD)
                            .padding(.top, CLTheme.spacingSM)

                        searchBar
                        filterChips

                        if viewModel.isLoading {
                            ForEach(0..<3, id: \.self) { _ in
                                loadingCard
                            }
                        } else if viewModel.filteredCaregivers.isEmpty {
                            emptyState
                        } else {
                            caregiverList
                        }

                        emergencyBanner
                            .padding(.top, CLTheme.spacingSM)
                    }
                    .padding(.bottom, 100)
                }
            }
            .background(CLTheme.backgroundPrimary)
            .navigationDestination(isPresented: $showCaregiverProfile) {
                if let caregiver = selectedCaregiver {
                    CaregiverProfileView(caregiver: caregiver)
                        .environment(appState)
                }
            }
            .navigationDestination(isPresented: $showChat) {
                if let conv = chatConversation {
                    ChatDetailView(conversation: conv)
                        .environment(appState)
                }
            }
            .task {
                await viewModel.loadCaregivers(firestoreService: appState.firestoreService)
                await loadActiveConnection()
            }
            .onChange(of: appState.navigationResetToken) { _, _ in
                navigationPath = NavigationPath()
                showCaregiverProfile = false
            }
        }
    }

    // MARK: - Greeting

    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: CLTheme.spacingXS) {
            let hour = Calendar.current.component(.hour, from: Date())
            let greeting = hour < 12 ? "Good Morning" : (hour < 17 ? "Good Afternoon" : "Good Evening")

            Text("\(greeting),")
                .font(CLTheme.title2Font)
                .foregroundStyle(CLTheme.textSecondary)
            Text(appState.authService.userProfile?.fullName ?? "User")
                .font(CLTheme.largeTitleFont)
                .foregroundStyle(CLTheme.textPrimary)
        }
        .padding(.horizontal, CLTheme.spacingMD)
        .padding(.top, CLTheme.spacingSM)
    }

    // MARK: - Your Caregiver Card

    @ViewBuilder
    private var yourCaregiverCard: some View {
        if let caregiver = connectedCaregiver, let connection = activeConnection {
            VStack(alignment: .leading, spacing: CLTheme.spacingSM) {
                HStack {
                    Text("Your Caregiver")
                        .font(CLTheme.title2Font)
                        .foregroundStyle(CLTheme.textPrimary)
                    Spacer()
                    HStack(spacing: 4) {
                        Circle().fill(CLTheme.successGreen).frame(width: 8, height: 8)
                        Text("Connected")
                            .font(CLTheme.captionFont)
                            .foregroundStyle(CLTheme.successGreen)
                    }
                }
                .padding(.horizontal, CLTheme.spacingMD)

                VStack(spacing: 0) {
                    HStack(spacing: CLTheme.spacingMD) {
                        CaregiverAvatar(size: 65, imageURL: caregiver.imageURL, showVerified: caregiver.isVerified)

                        VStack(alignment: .leading, spacing: CLTheme.spacingXS) {
                            Text(caregiver.name)
                                .font(CLTheme.headlineFont)
                                .foregroundStyle(.white)
                            Text(caregiver.specialty)
                                .font(CLTheme.captionFont)
                                .foregroundStyle(.white.opacity(0.8))
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(CLTheme.starYellow)
                                Text(String(format: "%.1f", caregiver.rating))
                                    .font(CLTheme.calloutFont)
                                    .foregroundStyle(.white)
                                Text("•")
                                    .foregroundStyle(.white.opacity(0.5))
                                Text("$\(String(format: "%.0f", caregiver.hourlyRate))/hr")
                                    .font(CLTheme.calloutFont)
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                        }
                        Spacer()
                    }

                    HStack(spacing: CLTheme.spacingMD) {
                        Button {
                            openChatWithCaregiver(caregiver, connection: connection)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "message.fill")
                                    .font(.system(size: 14))
                                Text("Chat")
                                    .font(CLTheme.calloutFont)
                            }
                            .foregroundStyle(CLTheme.primaryNavy)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: CLTheme.cornerRadiusSM))
                        }

                        Button {
                            selectedCaregiver = caregiver
                            showCaregiverProfile = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "calendar.badge.plus")
                                    .font(.system(size: 14))
                                Text("Book Session")
                                    .font(CLTheme.calloutFont)
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(.white.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: CLTheme.cornerRadiusSM))
                        }
                    }
                    .padding(.top, CLTheme.spacingMD)
                }
                .padding(CLTheme.spacingMD)
                .background(
                    LinearGradient(
                        colors: [CLTheme.primaryNavy, CLTheme.accentBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: CLTheme.cornerRadiusXL))
                .shadow(color: CLTheme.primaryNavy.opacity(0.3), radius: 12, y: 6)
                .padding(.horizontal, CLTheme.spacingMD)
            }
        }
    }

    // MARK: - Quick Stats

    private var quickStatsRow: some View {
        HStack(spacing: CLTheme.spacingMD) {
            statCard(icon: "person.2.fill", value: "\(viewModel.caregivers.count)", label: "Caregivers", color: CLTheme.accentBlue)
            statCard(icon: "link.circle.fill", value: activeConnection != nil ? "1" : "0", label: "Connected", color: CLTheme.successGreen)
            statCard(icon: "bubble.left.fill", value: "\(appState.chatService.conversations.count)", label: "Chats", color: CLTheme.tealAccent)
        }
        .padding(.horizontal, CLTheme.spacingMD)
    }

    private func statCard(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: CLTheme.spacingSM) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)
            Text(value)
                .font(CLTheme.headlineFont)
                .foregroundStyle(CLTheme.textPrimary)
            Text(label)
                .font(CLTheme.captionFont)
                .foregroundStyle(CLTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, CLTheme.spacingMD)
        .background(CLTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: CLTheme.cornerRadiusLG))
        .shadow(color: CLTheme.shadowLight, radius: 4)
    }

    // MARK: - Search & Filter

    private var searchBar: some View {
        HStack(spacing: CLTheme.spacingSM) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundStyle(CLTheme.textTertiary)
            TextField("Search by name or specialty...", text: $viewModel.searchText)
                .font(CLTheme.bodyFont)
                .onChange(of: viewModel.searchText) { _, _ in
                    viewModel.applyFilters()
                }
        }
        .padding(.horizontal, CLTheme.spacingMD)
        .frame(height: 48)
        .background(CLTheme.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: CLTheme.cornerRadiusMD))
        .padding(.horizontal, CLTheme.spacingMD)
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: CLTheme.spacingSM) {
                ForEach(Caregiver.CareCategory.allCases, id: \.self) { category in
                    CLChip(
                        title: category.rawValue,
                        isSelected: viewModel.selectedCategory == category
                    ) {
                        viewModel.selectCategory(category)
                    }
                }
            }
            .padding(.horizontal, CLTheme.spacingMD)
        }
    }

    // MARK: - List

    private var caregiverList: some View {
        LazyVStack(spacing: CLTheme.spacingMD) {
            ForEach(viewModel.filteredCaregivers) { caregiver in
                CaregiverCardView(caregiver: caregiver)
                    .onTapGesture {
                        selectedCaregiver = caregiver
                        showCaregiverProfile = true
                    }
                    .padding(.horizontal, CLTheme.spacingMD)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: CLTheme.spacingMD) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 48))
                .foregroundStyle(CLTheme.textTertiary)
            Text("No caregivers available")
                .font(CLTheme.headlineFont)
                .foregroundStyle(CLTheme.textSecondary)
            Text("New caregivers are registering every day. Check back soon!")
                .font(CLTheme.bodyFont)
                .foregroundStyle(CLTheme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, CLTheme.spacingXL)
        .padding(.horizontal, CLTheme.spacingMD)
    }

    private var emergencyBanner: some View {
        HStack {
            VStack(alignment: .leading, spacing: CLTheme.spacingSM) {
                Text("Emergency Care?")
                    .font(CLTheme.title2Font)
                    .foregroundStyle(.white)
                Text("Connect with on-call specialists in less than 15 minutes.")
                    .font(CLTheme.captionFont)
                    .foregroundStyle(.white.opacity(0.9))

                Button {} label: {
                    Text("Learn More")
                        .font(CLTheme.calloutFont)
                        .foregroundStyle(CLTheme.primaryNavy)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.white)
                        .clipShape(Capsule())
                }
            }
            Spacer()
        }
        .padding(CLTheme.spacingLG)
        .background(
            LinearGradient(
                colors: [CLTheme.primaryNavy, CLTheme.accentBlue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: CLTheme.cornerRadiusXL))
        .padding(.horizontal, CLTheme.spacingMD)
    }

    private var loadingCard: some View {
        CLCard {
            HStack(spacing: CLTheme.spacingMD) {
                Circle()
                    .fill(CLTheme.backgroundSecondary)
                    .frame(width: 60, height: 60)
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(CLTheme.backgroundSecondary)
                        .frame(width: 120, height: 14)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(CLTheme.backgroundSecondary)
                        .frame(width: 80, height: 12)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(CLTheme.backgroundSecondary)
                        .frame(width: 160, height: 12)
                }
            }
        }
        .padding(.horizontal, CLTheme.spacingMD)
        .shimmerEffect(true)
    }

    // MARK: - Data Loading

    private func loadActiveConnection() async {
        let userId = appState.authService.currentUser?.uid ?? ""
        activeConnection = try? await appState.firestoreService.fetchActiveConnectionForUser(userId)
        if let conn = activeConnection {
            connectedCaregiver = try? await appState.firestoreService.fetchCaregiver(id: conn.caregiverId)
        }
    }

    private func openChatWithCaregiver(_ caregiver: Caregiver, connection: Connection) {
        Task {
            let userId = appState.authService.currentUser?.uid ?? ""
            let userName = appState.authService.userProfile?.fullName ?? "User"
            let conv = try? await appState.chatService.getOrCreateConversation(
                userId: userId,
                userName: userName,
                caregiverId: caregiver.id,
                caregiverName: caregiver.name,
                caregiverSpecialty: caregiver.specialty
            )
            chatConversation = conv
            showChat = true
        }
    }
}

#Preview {
    HomeView()
        .environment(AppState())
}
