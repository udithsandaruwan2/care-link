import SwiftUI
import FirebaseAuth

struct CaregiverHomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase
    @Binding var suppressMainTabBar: Bool

    @State private var bookings: [Booking] = []
    @State private var showDashboard = false
    @State private var isLoading = true
    @State private var activePatientSelection: CaregiverActivePatientSelection?
    @State private var activePatientProfile: CLUser?
    @State private var selectedProfileBooking: Booking?
    @State private var showMedicalRecords = false
    @State private var showPatientProfile = false
    @State private var showChat = false
    @State private var chatConversation: ChatConversation?
    @State private var isRequestingCancellation = false

    private var openCareStatuses: Set<Booking.BookingStatus> {
        [.awaitingCaregiver, .pending, .confirmed, .inProgress]
    }

    private var activePatientBooking: Booking? {
        if let patientId = activePatientSelection?.patientId,
           let selectedMatch = bookings.first(where: {
               ($0.userId == patientId || $0.careRecipientId == patientId) && openCareStatuses.contains($0.status)
           }) {
            return selectedMatch
        }
        return bookings.first { openCareStatuses.contains($0.status) }
    }

    private var pendingCount: Int {
        bookings.filter { $0.status.needsCaregiverAction }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CLTheme.spacingLG) {
                    greetingSection
                    if let booking = activePatientBooking {
                        activePatientCard(activePatientProfile, booking: booking)
                    } else if let profile = activePatientProfile {
                        selectedButNotActiveCard(profile)
                    } else {
                        noActivePatientCard
                    }
                    quickStats
                    CLButton(
                        title: "Open Caregiver Dashboard",
                        icon: "rectangle.grid.2x2.fill",
                        accessibilityHintText: String(localized: "Shows patients, appointments, and booking actions")
                    ) {
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
            .navigationDestination(isPresented: $showMedicalRecords) {
                if let profile = activePatientProfile {
                    MedicalRecordsView(
                        patientId: profile.id,
                        patientName: profile.fullName,
                        startInAddMode: false
                    )
                    .environment(appState)
                }
            }
            .navigationDestination(isPresented: $showPatientProfile) {
                PatientProfileView(patient: activePatientProfile, booking: selectedProfileBooking ?? activePatientBooking)
                    .environment(appState)
            }
            .navigationDestination(isPresented: $showChat) {
                if let conv = chatConversation {
                    ChatDetailView(conversation: conv)
                        .environment(appState)
                }
            }
            .task { await loadHomeData() }
            .onAppear {
                syncMainTabBarVisibility()
                Task { await loadHomeData() }
            }
            .onChange(of: showDashboard) { _, _ in syncMainTabBarVisibility() }
            .onChange(of: showDashboard) { _, isShowing in
                if !isShowing {
                    Task { await loadHomeData() }
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task { await loadHomeData() }
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

    private func activePatientCard(_ patient: CLUser?, booking: Booking) -> some View {
        let patientName = patient?.fullName
            ?? (activePatientSelection?.patientName.isEmpty == false ? activePatientSelection?.patientName : nil)
            ?? (booking.patientName.isEmpty ? "Patient" : booking.patientName)
        let isLiveSession = booking.status == .inProgress || booking.status == .confirmed

        return CLCard {
            VStack(alignment: .leading, spacing: CLTheme.spacingMD) {
                HStack {
                    Text("Active patient")
                        .font(CLTheme.title2Font)
                        .foregroundStyle(CLTheme.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Text(isLiveSession ? "LIVE" : "REQUESTED")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(isLiveSession ? CLTheme.successGreen : CLTheme.warningOrange)
                        .clipShape(Capsule())
                        .accessibilityLabel(
                            isLiveSession
                                ? String(localized: "Live session")
                                : String(localized: "Requested session")
                        )
                }
                .accessibilityElement(children: .combine)
                Text(patientName)
                    .font(CLTheme.headlineFont)
                    .foregroundStyle(CLTheme.primaryNavy)
                Text(patient?.phoneNumber.isEmpty == false ? patient?.phoneNumber ?? "" : "No phone on file")
                    .font(CLTheme.captionFont)
                    .foregroundStyle(CLTheme.textSecondary)

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

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: CLTheme.spacingSM) {
                        Button {
                            if let patient {
                                openChatWithActivePatient(patient)
                            } else {
                                openChatWithActiveBooking(booking)
                            }
                        } label: {
                            Label("Message", systemImage: "message.fill")
                                .font(CLTheme.calloutFont)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(CLTheme.primaryNavy)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        if let url = phoneURL(for: patient?.phoneNumber ?? "") {
                            Link(destination: url) {
                                Label("Call", systemImage: "phone.fill")
                                    .font(CLTheme.calloutFont)
                                    .foregroundStyle(CLTheme.primaryNavy)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(CLTheme.lightBlue)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }

                        if activePatientProfile != nil {
                            Button {
                                showMedicalRecords = true
                            } label: {
                                Label("Records", systemImage: "doc.text.fill")
                                    .font(CLTheme.calloutFont)
                                    .foregroundStyle(CLTheme.primaryNavy)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(CLTheme.lightBlue)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }

                        Button {
                            selectedProfileBooking = booking
                            showPatientProfile = true
                        } label: {
                            Label("Profile", systemImage: "person.crop.circle")
                                .font(CLTheme.calloutFont)
                                .foregroundStyle(CLTheme.primaryNavy)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(CLTheme.lightBlue)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }

                if booking.cancellationRequestedByUid == nil {
                    Button {
                        requestCancellation(for: booking)
                    } label: {
                        HStack {
                            if isRequestingCancellation {
                                ProgressView()
                                    .tint(CLTheme.warningOrange)
                            } else {
                                Image(systemName: "xmark.circle")
                            }
                            Text(isRequestingCancellation ? "Requesting..." : "Request cancellation")
                        }
                        .font(CLTheme.calloutFont)
                        .foregroundStyle(CLTheme.warningOrange)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(CLTheme.warningOrange.opacity(0.12))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(isRequestingCancellation)
                    .accessibilityLabel(String(localized: "Request cancellation"))
                    .accessibilityHint(String(localized: "Asks to cancel this booking"))
                    .careLinkAccessibilityValue(isRequestingCancellation ? String(localized: "Processing") : nil)
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.badge.checkmark")
                            .foregroundStyle(CLTheme.warningOrange)
                        Text("Cancellation already requested")
                            .font(CLTheme.captionFont)
                            .foregroundStyle(CLTheme.textSecondary)
                    }
                }
            }
        }
        .padding(.horizontal, CLTheme.spacingMD)
    }

    private func selectedButNotActiveCard(_ patient: CLUser) -> some View {
        CLCard {
            VStack(alignment: .leading, spacing: CLTheme.spacingSM) {
                Text("No active session")
                    .font(CLTheme.title2Font)
                    .foregroundStyle(CLTheme.textPrimary)
                Text("\(patient.fullName) is selected, but there is no open booking request or live session.")
                    .font(CLTheme.bodyFont)
                    .foregroundStyle(CLTheme.textSecondary)
            }
        }
        .padding(.horizontal, CLTheme.spacingMD)
    }

    private var noActivePatientCard: some View {
        CLCard {
            VStack(alignment: .leading, spacing: CLTheme.spacingSM) {
                Text("No active patient selected")
                    .font(CLTheme.title2Font)
                    .foregroundStyle(CLTheme.textPrimary)
                Text("Open dashboard and set one patient as Active. Only one patient can be active at a time.")
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
        .accessibilityElement(children: .combine)
    }

    private func loadHomeData() async {
        isLoading = true
        let caregiverId = appState.authService.currentUser?.uid ?? ""
        async let bookingsTask = appState.firestoreService.fetchCaregiverBookings(for: caregiverId)
        async let activeSelectionTask = appState.firestoreService.fetchActivePatientForCaregiver(caregiverId: caregiverId)
        bookings = (try? await bookingsTask) ?? []
        activePatientSelection = try? await activeSelectionTask

        // Do NOT auto-select a patient from open bookings. Caregiver must explicitly
        // set an active patient via the dashboard. This prevents accidental fallback
        // to the first open booking and matches the new semantics.

        if let patientId = activePatientSelection?.patientId {
            activePatientProfile = try? await appState.firestoreService.fetchUser(patientId)
        } else {
            activePatientProfile = nil
        }
        isLoading = false
    }

    private func openChatWithActivePatient(_ patient: CLUser) {
        Task {
            let caregiverId = appState.authService.currentUser?.uid ?? ""
            let caregiverName = appState.authService.userProfile?.fullName ?? "Caregiver"
            let conv = try? await appState.chatService.getOrCreateConversation(
                userId: patient.id,
                userName: patient.fullName,
                caregiverId: caregiverId,
                caregiverName: caregiverName,
                caregiverSpecialty: ""
            )
            chatConversation = conv
            showChat = true
        }
    }

    private func openChatWithActiveBooking(_ booking: Booking) {
        Task {
            let caregiverId = appState.authService.currentUser?.uid ?? ""
            let caregiverName = appState.authService.userProfile?.fullName ?? "Caregiver"
            let userName = booking.patientName.isEmpty ? "Patient" : booking.patientName
            let conv = try? await appState.chatService.getOrCreateConversation(
                userId: booking.userId,
                userName: userName,
                caregiverId: caregiverId,
                caregiverName: caregiverName,
                caregiverSpecialty: ""
            )
            chatConversation = conv
            showChat = true
        }
    }

    private func phoneURL(for phone: String) -> URL? {
        let cleaned = phone
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
        guard !cleaned.isEmpty else { return nil }
        return URL(string: "tel:\(cleaned)")
    }

    private func syncMainTabBarVisibility() {
        suppressMainTabBar = showDashboard
    }

    private func requestCancellation(for booking: Booking) {
        guard !isRequestingCancellation else { return }
        isRequestingCancellation = true
        let caregiverUid = appState.authService.currentUser?.uid ?? ""
        Task {
            defer { isRequestingCancellation = false }
            try? await appState.firestoreService.requestBookingCancellation(
                bookingId: booking.id,
                requesterUid: caregiverUid,
                requesterRole: .caregiver
            )
            await loadHomeData()
        }
    }
}

