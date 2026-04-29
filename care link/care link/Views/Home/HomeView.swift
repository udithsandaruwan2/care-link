import SwiftUI
import FirebaseAuth

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Binding var suppressMainTabBar: Bool
    @State private var viewModel = HomeViewModel()
    @State private var selectedCaregiver: Caregiver?
    @State private var showCaregiverProfile = false
    @State private var navigationPath = NavigationPath()

    @State private var activeConnection: Connection?
    @State private var connectedCaregiver: Caregiver?
    /// Shown when the user has an accepted booking (even without a separate “connection”).
    @State private var activeBooking: Booking?
    @State private var pendingBooking: Booking?
    @State private var bookingCaregiver: Caregiver?
    @State private var showChat = false
    @State private var chatConversation: ChatConversation?
    @State private var showFilters = false
    @State private var showCancelRequestConfirmation = false
    @State private var isCancellingRequest = false
    @State private var lastKnownCareBookingId: String?
    @State private var isReconcilingBookingState = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                CLNavigationBar(filterAction: { showFilters = true })

                ScrollView {
                    VStack(alignment: .leading, spacing: CLTheme.spacingMD) {
                        if !appState.networkMonitor.isConnected {
                            internetRequiredBanner
                        }
                        greetingSection
                        yourCaregiverCard
                        if hasAssignedCaregiverDashboard {
                            assignedCaregiverMonitoringSection
                        } else {
                            quickStatsRow

                            Text("Available Caregivers")
                                .font(CLTheme.title2Font)
                                .foregroundStyle(CLTheme.textPrimary)
                                .padding(.horizontal, CLTheme.spacingMD)
                                .padding(.top, CLTheme.spacingSM)
                            if !viewModel.recommendedCaregivers.isEmpty {
                                Text("Ranked for you using on-device intelligence")
                                    .font(CLTheme.captionFont)
                                    .foregroundStyle(CLTheme.textTertiary)
                                    .padding(.horizontal, CLTheme.spacingMD)
                            }

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
                if appState.networkMonitor.isConnected {
                    await viewModel.loadCaregivers(firestoreService: appState.firestoreService)
                } else {
                    viewModel.filteredCaregivers = []
                    viewModel.caregivers = []
                }
                let history = await loadBookingHistory()
                viewModel.updateRecommendations(
                    recommendationService: appState.coreMLRecommendationService,
                    bookingHistory: history
                )
                await loadActiveConnection()
                await loadActiveBookingCard(from: history)
                if UserDefaults.standard.bool(forKey: "carelink.healthKitSyncEnabled") {
                    await appState.healthKitService.refreshAuthorizationStatus()
                    await appState.healthKitService.refreshMetrics()
                }
            }
            .onChange(of: appState.navigationResetToken) { _, _ in
                navigationPath = NavigationPath()
                showCaregiverProfile = false
                syncMainTabBarVisibility()
            }
            .alert("Cancel Request", isPresented: $showCancelRequestConfirmation) {
                Button("Keep Request", role: .cancel) {}
                Button("Cancel Request", role: .destructive) {
                    cancelCurrentBookingRequest()
                }
            } message: {
                Text("This will cancel your current caregiver request.")
            }
            .onAppear { syncMainTabBarVisibility() }
            .onAppear {
                Task {
                    guard UserDefaults.standard.bool(forKey: "carelink.healthKitSyncEnabled") else { return }
                    await appState.healthKitService.refreshMetrics()
                }
            }
            .onAppear {
                let userId = appState.authService.currentUser?.uid ?? ""
                appState.firestoreService.listenToBookingsForUser(userId) { bookings in
                    Task { @MainActor in
                        applyRealtimeBookingUpdate(bookings)
                    }
                }
            }
            .onDisappear {
                appState.firestoreService.stopListeningToBookingsForUser()
            }
            .onChange(of: showCaregiverProfile) { _, _ in syncMainTabBarVisibility() }
            .onChange(of: showChat) { _, _ in syncMainTabBarVisibility() }
        }
        .sheet(isPresented: $showFilters) {
            filterSheet
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    private var hasAssignedCaregiverDashboard: Bool {
        lastKnownCareBookingId != nil || heroBooking != nil || pendingBooking != nil
    }

    private func syncMainTabBarVisibility() {
        suppressMainTabBar = showCaregiverProfile || showChat
    }

    // MARK: - Greeting

    private var internetRequiredBanner: some View {
        HStack(spacing: CLTheme.spacingSM) {
            Image(systemName: "wifi.exclamationmark")
                .foregroundStyle(CLTheme.warningOrange)
            Text("Internet is off. Turn on internet for caregiver search, booking, and chat.")
                .font(CLTheme.captionFont)
                .foregroundStyle(CLTheme.textSecondary)
            Spacer()
        }
        .padding(CLTheme.spacingMD)
        .background(CLTheme.warningOrange.opacity(0.12))
        .clipShape(CLTheme.continuousRect(cornerRadius: CLTheme.cornerRadiusMD))
        .padding(.horizontal, CLTheme.spacingMD)
    }

    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: CLTheme.spacingSM) {
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

    private var heroCaregiver: Caregiver? {
        bookingCaregiver ?? connectedCaregiver
    }

    private var heroBooking: Booking? {
        activeBooking ?? pendingBooking
    }

    private var heroConnection: Connection? {
        activeConnection
    }

    @ViewBuilder
    private var yourCaregiverCard: some View {
        if let booking = heroBooking ?? activeBooking {
            VStack(alignment: .leading, spacing: CLTheme.spacingSM) {
                HStack {
                    Text("Your booked caregiver")
                        .font(CLTheme.title2Font)
                        .foregroundStyle(CLTheme.textPrimary)
                    Spacer()
                    HStack(spacing: 4) {
                        Circle().fill(CLTheme.successGreen).frame(width: 8, height: 8)
                        Text("Confirmed")
                            .font(CLTheme.captionFont)
                            .foregroundStyle(CLTheme.successGreen)
                    }
                }
                .padding(.horizontal, CLTheme.spacingMD)

                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "calendar")
                            .font(.system(size: 12))
                        Text("\(booking.date.formatted(date: .abbreviated, time: .omitted)) · \(booking.startTime.formatted(date: .omitted, time: .shortened)) – \(booking.endTime.formatted(date: .omitted, time: .shortened))")
                            .font(CLTheme.captionFont)
                        Spacer()
                        Text("$\(String(format: "%.0f", booking.totalCost))")
                            .font(CLTheme.calloutFont)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.bottom, CLTheme.spacingSM)

                    HStack(spacing: CLTheme.spacingMD) {
                        CaregiverAvatar(
                            size: 65,
                            imageURL: heroCaregiver?.imageURL ?? booking.caregiverImageURL,
                            showVerified: heroCaregiver?.isVerified ?? false
                        )

                        VStack(alignment: .leading, spacing: CLTheme.spacingXS) {
                            Text(heroCaregiver?.name ?? booking.caregiverName)
                                .font(CLTheme.headlineFont)
                                .foregroundStyle(.white)
                            Text(heroCaregiver?.specialty ?? booking.caregiverSpecialty)
                                .font(CLTheme.captionFont)
                                .foregroundStyle(.white.opacity(0.8))
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(CLTheme.starYellow)
                                Text(String(format: "%.1f", heroCaregiver?.rating ?? booking.caregiverRating))
                                    .font(CLTheme.calloutFont)
                                    .foregroundStyle(.white)
                                Text("•")
                                    .foregroundStyle(.white.opacity(0.5))
                                Text("$\(String(format: "%.0f", heroCaregiver?.hourlyRate ?? (booking.totalCost / max(booking.duration, 0.5))))/hr")
                                    .font(CLTheme.calloutFont)
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                        }
                        Spacer()
                    }

                    HStack(spacing: CLTheme.spacingMD) {
                        Button {
                            if let caregiver = heroCaregiver, let conn = heroConnection {
                                openChatWithCaregiver(caregiver, connection: conn)
                            } else if let caregiver = heroCaregiver {
                                openChatWithCaregiverUnconnected(caregiver)
                            } else {
                                openChatForBookingFallback(booking)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "message.fill")
                                    .font(.system(size: 14))
                                Text("Chat")
                                    .font(CLTheme.calloutFont)
                            }
                            .foregroundStyle(CLTheme.primaryNavy)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.white)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            if let caregiver = heroCaregiver {
                                selectedCaregiver = caregiver
                                showCaregiverProfile = true
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "calendar.badge.plus")
                                    .font(.system(size: 14))
                                Text("Details")
                                    .font(CLTheme.calloutFont)
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.white.opacity(0.22))
                            .clipShape(Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(.white.opacity(0.35), lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(heroCaregiver == nil)
                    }
                    .padding(.top, CLTheme.spacingMD)

                    if booking.status == .awaitingCaregiver || booking.status == .pending || booking.status == .confirmed {
                        CLButton(
                            title: isCancellingRequest ? "Sending..." : "Request Cancellation",
                            icon: "xmark.circle",
                            style: .outline,
                            isLoading: isCancellingRequest
                        ) {
                            showCancelRequestConfirmation = true
                        }
                        .padding(.top, CLTheme.spacingMD)
                    }
                }
                .padding(CLTheme.spacingMD)
                .background(
                    LinearGradient(
                        colors: [CLTheme.primaryNavy, CLTheme.accentBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(CLTheme.continuousRect(cornerRadius: CLTheme.cornerRadiusXL))
                .shadow(color: CLTheme.primaryNavy.opacity(0.3), radius: 14, y: 6)
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

    // MARK: - Assigned caregiver dashboard (Fitness-inspired)

    @ViewBuilder
    private var assignedCaregiverMonitoringSection: some View {
        if let booking = heroBooking ?? activeBooking {
            VStack(alignment: .leading, spacing: CLTheme.spacingMD) {
                Text(activeBooking != nil ? "Live Care Session" : "Care Request In Progress")
                    .font(CLTheme.title2Font)
                    .foregroundStyle(CLTheme.textPrimary)
                    .padding(.horizontal, CLTheme.spacingMD)

                CLCard {
                    VStack(alignment: .leading, spacing: CLTheme.spacingMD) {
                        HStack(spacing: CLTheme.spacingMD) {
                            CaregiverAvatar(
                                size: 56,
                                imageURL: heroCaregiver?.imageURL ?? booking.caregiverImageURL,
                                showVerified: heroCaregiver?.isVerified ?? false
                            )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(heroCaregiver?.name ?? booking.caregiverName)
                                    .font(CLTheme.headlineFont)
                                    .foregroundStyle(CLTheme.textPrimary)
                                Text(heroCaregiver?.specialty ?? booking.caregiverSpecialty)
                                    .font(CLTheme.captionFont)
                                    .foregroundStyle(CLTheme.textSecondary)
                            }
                            Spacer()
                            Text(activeBooking != nil ? "Assigned" : "Requested")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(activeBooking != nil ? CLTheme.successGreen : CLTheme.warningOrange)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background((activeBooking != nil ? CLTheme.successGreen : CLTheme.warningOrange).opacity(0.12))
                                .clipShape(Capsule())
                        }

                        HStack {
                            Label(
                                "\(booking.startTime.formatted(date: .omitted, time: .shortened)) - \(booking.endTime.formatted(date: .omitted, time: .shortened))",
                                systemImage: "clock"
                            )
                            .font(CLTheme.captionFont)
                            .foregroundStyle(CLTheme.textSecondary)
                            Spacer()
                            Label(booking.status.rawValue, systemImage: "waveform.path.ecg")
                                .font(CLTheme.captionFont)
                                .foregroundStyle(CLTheme.accentBlue)
                        }
                    }
                }
                .padding(.horizontal, CLTheme.spacingMD)

                if activeBooking != nil {
                    TimelineView(.periodic(from: Date(), by: 1)) { context in
                        let metrics = monitoringMetrics(now: context.date)
                        VStack(spacing: CLTheme.spacingMD) {
                            monitoringHeroCard(metrics: metrics)
                            HStack(spacing: CLTheme.spacingMD) {
                                monitoringTile(
                                    title: "Heart Rate",
                                    value: "\(metrics.heartRate)",
                                    unit: "BPM",
                                    icon: "heart.fill",
                                    color: CLTheme.errorRed
                                )
                                monitoringTile(
                                    title: "SpO2",
                                    value: "\(metrics.oxygen)",
                                    unit: "%",
                                    icon: "lungs.fill",
                                    color: CLTheme.tealAccent
                                )
                            }
                            HStack(spacing: CLTheme.spacingMD) {
                                monitoringTile(
                                    title: "Progress",
                                    value: "\(metrics.progress)",
                                    unit: "%",
                                    icon: "figure.walk",
                                    color: CLTheme.accentBlue
                                )
                                monitoringTile(
                                    title: "Stress",
                                    value: metrics.stress,
                                    unit: "Level",
                                    icon: "waveform",
                                    color: CLTheme.warningOrange
                                )
                            }
                            monitoringTile(
                                title: "Respiratory",
                                value: "\(metrics.respiratory)",
                                unit: "RPM",
                                icon: "wind",
                                color: CLTheme.tealAccent
                            )
                        }
                    }
                    .padding(.horizontal, CLTheme.spacingMD)
                } else {
                    CLCard {
                        VStack(alignment: .leading, spacing: CLTheme.spacingSM) {
                            Text("Waiting for caregiver response")
                                .font(CLTheme.headlineFont)
                                .foregroundStyle(CLTheme.textPrimary)
                            Text("Your request was sent successfully. You will see live monitoring here as soon as it is confirmed.")
                                .font(CLTheme.calloutFont)
                                .foregroundStyle(CLTheme.textSecondary)
                            HStack(spacing: CLTheme.spacingSM) {
                                Image(systemName: "clock.badge.checkmark")
                                    .foregroundStyle(CLTheme.warningOrange)
                                Text("Status updates in real-time")
                                    .font(CLTheme.captionFont)
                                    .foregroundStyle(CLTheme.textTertiary)
                            }
                        }
                    }
                    .padding(.horizontal, CLTheme.spacingMD)
                }
            }
        }
    }

    private func monitoringHeroCard(metrics: MonitoringMetrics) -> some View {
        VStack(alignment: .leading, spacing: CLTheme.spacingMD) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Realtime Monitoring")
                        .font(CLTheme.headlineFont)
                        .foregroundStyle(.white)
                    Text(appState.healthKitService.isAuthorized ? "Synced from Apple Health" : "Updated every second")
                        .font(CLTheme.captionFont)
                        .foregroundStyle(.white.opacity(0.82))
                }
                Spacer()
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
            }

            ZStack {
                Circle()
                    .stroke(.white.opacity(0.2), lineWidth: 9)
                Circle()
                    .trim(from: 0, to: CGFloat(metrics.progress) / 100)
                    .stroke(.white, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text("\(metrics.progress)%")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Session goal")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .frame(width: 120, height: 120)
        }
        .padding(CLTheme.spacingMD)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [CLTheme.primaryNavy, CLTheme.accentBlue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(CLTheme.continuousRect(cornerRadius: CLTheme.cornerRadiusXL))
        .shadow(color: CLTheme.primaryNavy.opacity(0.24), radius: 12, y: 4)
    }

    private func monitoringTile(
        title: String,
        value: String,
        unit: String,
        icon: String,
        color: Color
    ) -> some View {
        CLCard {
            VStack(alignment: .leading, spacing: CLTheme.spacingSM) {
                HStack {
                    Image(systemName: icon)
                        .foregroundStyle(color)
                    Spacer()
                }
                Text(title.uppercased())
                    .font(CLTheme.smallFont)
                    .tracking(1)
                    .foregroundStyle(CLTheme.textTertiary)
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(CLTheme.textPrimary)
                    Text(unit)
                        .font(CLTheme.captionFont)
                        .foregroundStyle(CLTheme.textSecondary)
                }
            }
        }
    }

    private struct MonitoringMetrics {
        var heartRate: Int
        var oxygen: Int
        var progress: Int
        var stress: String
        var respiratory: Int
    }

    private func monitoringMetrics(now: Date) -> MonitoringMetrics {
        if appState.healthKitService.isAuthorized,
           UserDefaults.standard.bool(forKey: "carelink.healthKitSyncEnabled") {
            let hk = appState.healthKitService.metrics
            return MonitoringMetrics(
                heartRate: hk.heartRateBPM ?? 0,
                oxygen: hk.oxygenPercent ?? 0,
                progress: min(100, max(0, hk.heartRateBPM ?? 0)),
                stress: derivedStressLabel(heartRate: hk.heartRateBPM),
                respiratory: hk.respiratoryRate ?? 0
            )
        }
        let second = Calendar.current.component(.second, from: now)
        let minute = Calendar.current.component(.minute, from: now)
        let heartRate = 68 + Int((sin(Double(second) / 60 * .pi * 2) * 7).rounded())
        let oxygen = 96 + (second % 3)
        let progress = min(98, 40 + (minute % 50))
        let stress: String = {
            switch (second / 15) % 4 {
            case 0: return "Low"
            case 1, 2: return "Moderate"
            default: return "Low"
            }
        }()
        let respiratory = 14 + ((second / 8) % 4)
        return MonitoringMetrics(
            heartRate: max(55, heartRate),
            oxygen: oxygen,
            progress: progress,
            stress: stress,
            respiratory: respiratory
        )
    }

    private func derivedStressLabel(heartRate: Int?) -> String {
        guard let heartRate else { return "Unknown" }
        if heartRate < 72 { return "Low" }
        if heartRate < 90 { return "Moderate" }
        return "Elevated"
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
        .clipShape(CLTheme.continuousRect(cornerRadius: CLTheme.cornerRadiusLG))
        .shadow(color: CLTheme.shadowLight, radius: 6, y: 2)
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
        .frame(height: 50)
        .background(CLTheme.backgroundSecondary)
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .stroke(CLTheme.divider.opacity(0.55), lineWidth: 1)
        }
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

    private var filterSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: CLTheme.spacingLG) {
                VStack(alignment: .leading, spacing: CLTheme.spacingSM) {
                    Text("Sort by")
                        .font(CLTheme.headlineFont)
                        .foregroundStyle(CLTheme.textPrimary)
                    Picker("Sort by", selection: $viewModel.selectedSort) {
                        ForEach(HomeViewModel.SortOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                VStack(alignment: .leading, spacing: CLTheme.spacingSM) {
                    Toggle("Budget filter", isOn: $viewModel.budgetFilterEnabled)
                        .tint(CLTheme.tealAccent)
                        .font(CLTheme.calloutFont)

                    if viewModel.budgetFilterEnabled {
                        VStack(alignment: .leading, spacing: CLTheme.spacingXS) {
                            HStack {
                                Text("Max hourly rate")
                                    .font(CLTheme.calloutFont)
                                    .foregroundStyle(CLTheme.textSecondary)
                                Spacer()
                                Text("$\(Int(viewModel.maxBudget))/hr")
                                    .font(CLTheme.calloutFont.weight(.semibold))
                                    .foregroundStyle(CLTheme.textPrimary)
                            }
                            Slider(value: $viewModel.maxBudget, in: 20...300, step: 5)
                                .tint(CLTheme.accentBlue)
                        }
                    }
                }

                Spacer()

                HStack(spacing: CLTheme.spacingMD) {
                    CLButton(title: "Reset", style: .outline) {
                        viewModel.selectedSort = .recommended
                        viewModel.budgetFilterEnabled = false
                        viewModel.maxBudget = 120
                        viewModel.applyFilters()
                        showFilters = false
                    }
                    CLButton(title: "Apply", icon: "checkmark") {
                        viewModel.applyFilters()
                        showFilters = false
                    }
                }
            }
            .padding(CLTheme.spacingMD)
            .navigationTitle("Caregiver Filters")
            .navigationBarTitleDisplayMode(.inline)
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
        .clipShape(CLTheme.continuousRect(cornerRadius: CLTheme.cornerRadiusXL))
        .padding(.horizontal, CLTheme.spacingMD)
    }

    private var loadingCard: some View {
        CLCard {
            HStack(spacing: CLTheme.spacingMD) {
                Circle()
                    .fill(CLTheme.backgroundSecondary)
                    .frame(width: 60, height: 60)
                VStack(alignment: .leading, spacing: 6) {
                    CLTheme.continuousRect(cornerRadius: CLTheme.cornerRadiusSM)
                        .fill(CLTheme.backgroundSecondary)
                        .frame(width: 120, height: 14)
                    CLTheme.continuousRect(cornerRadius: CLTheme.cornerRadiusSM)
                        .fill(CLTheme.backgroundSecondary)
                        .frame(width: 80, height: 12)
                    CLTheme.continuousRect(cornerRadius: CLTheme.cornerRadiusSM)
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
        } else {
            connectedCaregiver = nil
        }
    }

    /// Latest confirmed / in-progress booking drives the home hero when present.
    private func loadBookingHistory() async -> [Booking] {
        let userId = appState.authService.currentUser?.uid ?? ""
        guard !userId.isEmpty else { return [] }
        return (try? await appState.firestoreService.fetchBookings(for: userId)) ?? []
    }

    @MainActor
    private func applyRealtimeBookingUpdate(_ bookings: [Booking]) {
        let confirmedMatch = bookings.first { $0.status == .confirmed || $0.status == .inProgress }
        let pendingMatch = bookings.first { $0.status == .awaitingCaregiver || $0.status == .pending }
        if let active = confirmedMatch ?? pendingMatch {
            setCurrentCareBooking(active, isActive: confirmedMatch != nil)
            return
        }

        // Keep current care-flow UI sticky unless server explicitly reports terminal state
        // for the known booking.
        guard let knownId = lastKnownCareBookingId else {
            bookingCaregiver = nil
            activeBooking = nil
            pendingBooking = nil
            return
        }

        if let terminal = bookings.first(where: { $0.id == knownId }),
           terminal.status == .cancelled || terminal.status == .completed {
            activeBooking = nil
            pendingBooking = nil
            bookingCaregiver = nil
            lastKnownCareBookingId = nil
            return
        }

        // No explicit terminal signal for the known booking; keep current state.
        if activeBooking == nil && pendingBooking == nil {
            reconcileBookingStateFromServer()
        }
    }

    private func loadActiveBookingCard(from list: [Booking]? = nil) async {
        let loaded: [Booking]
        if let list {
            loaded = list
        } else {
            loaded = await loadBookingHistory()
        }
        let confirmedMatch = loaded.first { $0.status == .confirmed || $0.status == .inProgress }
        let pendingMatch = loaded.first { $0.status == .awaitingCaregiver || $0.status == .pending }
        if let booking = confirmedMatch ?? pendingMatch {
            await MainActor.run {
                setCurrentCareBooking(booking, isActive: confirmedMatch != nil)
            }
            let caregiver = try? await appState.firestoreService.fetchCaregiver(id: booking.caregiverId)
            await MainActor.run {
                if let caregiver {
                    bookingCaregiver = caregiver
                }
            }
            return
        }

        // Avoid clearing existing UI from possibly stale initial fetch.
        if activeBooking == nil && pendingBooking == nil && lastKnownCareBookingId == nil {
            bookingCaregiver = nil
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

    private func openChatWithCaregiverUnconnected(_ caregiver: Caregiver) {
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

    private func openChatForBookingFallback(_ booking: Booking) {
        Task {
            let userId = appState.authService.currentUser?.uid ?? ""
            let userName = appState.authService.userProfile?.fullName ?? "User"
            let conv = try? await appState.chatService.getOrCreateConversation(
                userId: userId,
                userName: userName,
                caregiverId: booking.caregiverId,
                caregiverName: booking.caregiverName,
                caregiverSpecialty: booking.caregiverSpecialty
            )
            chatConversation = conv
            showChat = true
        }
    }

    private func cancelCurrentBookingRequest() {
        guard let bookingId = (activeBooking ?? pendingBooking)?.id else { return }
        let patientUid = appState.authService.currentUser?.uid ?? ""
        isCancellingRequest = true
        Task {
            do {
                try await appState.firestoreService.requestBookingCancellation(
                    bookingId: bookingId,
                    requesterUid: patientUid,
                    requesterRole: .patient
                )
                if let booking = try? await appState.firestoreService.fetchBooking(bookingId: bookingId) {
                    await MainActor.run {
                        if activeBooking?.id == bookingId { activeBooking = booking }
                        if pendingBooking?.id == bookingId { pendingBooking = booking }
                    }
                }
            } catch {
                // Reuse global error surfaces elsewhere; UI is kept simple here.
            }
            await MainActor.run {
                isCancellingRequest = false
            }
        }
    }

    @MainActor
    private func setCurrentCareBooking(_ booking: Booking, isActive: Bool) {
        if isActive {
            activeBooking = booking
            pendingBooking = nil
        } else {
            pendingBooking = booking
            activeBooking = nil
        }
        lastKnownCareBookingId = booking.id

        Task {
            let caregiver = try? await appState.firestoreService.fetchCaregiver(id: booking.caregiverId)
            await MainActor.run {
                if let caregiver {
                    bookingCaregiver = caregiver
                }
            }
        }
    }

    @MainActor
    private func reconcileBookingStateFromServer() {
        guard !isReconcilingBookingState else { return }
        isReconcilingBookingState = true
        Task {
            let fresh = await loadBookingHistory()
            await MainActor.run {
                let confirmed = fresh.first { $0.status == .confirmed || $0.status == .inProgress }
                let pending = fresh.first { $0.status == .awaitingCaregiver || $0.status == .pending }

                if let booking = confirmed {
                    setCurrentCareBooking(booking, isActive: true)
                } else if let booking = pending {
                    setCurrentCareBooking(booking, isActive: false)
                } else {
                    // Clear only if the known booking reached terminal state or truly disappeared.
                    if let knownId = lastKnownCareBookingId,
                       let terminal = fresh.first(where: { $0.id == knownId }),
                       (terminal.status == .cancelled || terminal.status == .completed) {
                        activeBooking = nil
                        pendingBooking = nil
                        bookingCaregiver = nil
                        lastKnownCareBookingId = nil
                    } else if lastKnownCareBookingId == nil {
                        activeBooking = nil
                        pendingBooking = nil
                        bookingCaregiver = nil
                    }
                }
                isReconcilingBookingState = false
            }
        }
    }
}

#Preview {
    HomeView(suppressMainTabBar: .constant(false))
        .environment(AppState())
}
