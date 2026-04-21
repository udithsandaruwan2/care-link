import SwiftUI
import FirebaseAuth

struct CaregiverHomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase
    @Binding var suppressMainTabBar: Bool

    @State private var bookings: [Booking] = []
    @State private var showDashboard = false
    @State private var isLoading = true

    private var activeBooking: Booking? {
        bookings.first { $0.status == .confirmed || $0.status == .inProgress }
    }

    private var pendingCount: Int {
        bookings.filter { $0.status.needsCaregiverAction }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CLTheme.spacingLG) {
                    greetingSection
                    if let activeBooking {
                        bookedPatientCard(activeBooking)
                    } else {
                        noActiveBookingCard
                    }
                    quickStats
                    CLButton(title: "Open Caregiver Dashboard", icon: "rectangle.grid.2x2.fill") {
                        showDashboard = true
                    }
                    .padding(.horizontal, CLTheme.spacingMD)
                }
                .padding(.vertical, CLTheme.spacingMD)
                .padding(.bottom, 100)
            }
            .background(CLTheme.backgroundPrimary)
            .navigationDestination(isPresented: $showDashboard) {
                CaregiverDashboardView()
                    .environment(appState)
            }
            .task { await loadBookings() }
            .onAppear {
                syncMainTabBarVisibility()
                Task { await loadBookings() }
            }
            .onChange(of: showDashboard) { _, _ in syncMainTabBarVisibility() }
            .onChange(of: showDashboard) { _, isShowing in
                if !isShowing {
                    Task { await loadBookings() }
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task { await loadBookings() }
                }
            }
        }
    }

    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: CLTheme.spacingXS) {
            let hour = Calendar.current.component(.hour, from: Date())
            let greeting = hour < 12 ? "Good Morning" : (hour < 17 ? "Good Afternoon" : "Good Evening")
            Text("\(greeting),")
                .font(CLTheme.title2Font)
                .foregroundStyle(CLTheme.textSecondary)
            Text("Dr. \(appState.authService.userProfile?.fullName ?? "Caregiver")")
                .font(CLTheme.largeTitleFont)
                .foregroundStyle(CLTheme.textPrimary)
        }
        .padding(.horizontal, CLTheme.spacingMD)
    }

    private func bookedPatientCard(_ booking: Booking) -> some View {
        CLCard {
            VStack(alignment: .leading, spacing: CLTheme.spacingMD) {
                Text("Current booking")
                    .font(CLTheme.title2Font)
                    .foregroundStyle(CLTheme.textPrimary)
                Text(booking.patientName.isEmpty ? "Patient" : booking.patientName)
                    .font(CLTheme.headlineFont)
                    .foregroundStyle(CLTheme.primaryNavy)
                Text("\(booking.date.formatted(date: .abbreviated, time: .omitted)) · \(booking.startTime.formatted(date: .omitted, time: .shortened))")
                    .font(CLTheme.captionFont)
                    .foregroundStyle(CLTheme.textSecondary)
                Text(booking.status.rawValue)
                    .font(CLTheme.captionFont)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(hex: booking.status.color))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, CLTheme.spacingMD)
    }

    private var noActiveBookingCard: some View {
        CLCard {
            VStack(alignment: .leading, spacing: CLTheme.spacingSM) {
                Text("No active booking")
                    .font(CLTheme.headlineFont)
                    .foregroundStyle(CLTheme.textPrimary)
                Text("You will see confirmed or in-progress visits here, similar to patient home.")
                    .font(CLTheme.bodyFont)
                    .foregroundStyle(CLTheme.textSecondary)
            }
        }
        .padding(.horizontal, CLTheme.spacingMD)
    }

    private var quickStats: some View {
        HStack(spacing: CLTheme.spacingMD) {
            statCard(title: "Pending", value: "\(pendingCount)")
            statCard(title: "Completed", value: "\(bookings.filter { $0.status == .completed }.count)")
        }
        .padding(.horizontal, CLTheme.spacingMD)
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(CLTheme.captionFont)
                .foregroundStyle(CLTheme.textSecondary)
            if isLoading {
                ProgressView()
            } else {
                Text(value)
                    .font(CLTheme.titleFont)
                    .foregroundStyle(CLTheme.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CLTheme.spacingMD)
        .background(CLTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: CLTheme.cornerRadiusLG, style: .continuous))
    }

    private func loadBookings() async {
        isLoading = true
        let caregiverId = appState.authService.currentUser?.uid ?? ""
        bookings = (try? await appState.firestoreService.fetchCaregiverBookings(for: caregiverId)) ?? []
        isLoading = false
    }

    private func syncMainTabBarVisibility() {
        suppressMainTabBar = showDashboard
    }
}

