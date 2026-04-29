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
    @State private var showMedicalRecords = false
    @State private var showChat = false
    @State private var chatConversation: ChatConversation?

    private var activePatientBooking: Booking? {
        guard let patientId = activePatientSelection?.patientId else { return nil }
        return bookings.first {
            $0.userId == patientId && ($0.status == .inProgress || $0.status == .confirmed)
        }
    }

    private var pendingCount: Int {
        bookings.filter { $0.status.needsCaregiverAction }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CLTheme.spacingLG) {
                    greetingSection
                    if let profile = activePatientProfile, let booking = activePatientBooking {
                        activePatientCard(profile, booking: booking)
                    } else if let profile = activePatientProfile {
                        selectedButNotActiveCard(profile)
                    } else {
                        noActivePatientCard
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

    private func activePatientCard(_ patient: CLUser, booking: Booking) -> some View {
        CLCard {
            VStack(alignment: .leading, spacing: CLTheme.spacingMD) {
                HStack {
                    Text("Active patient")
                        .font(CLTheme.title2Font)
                        .foregroundStyle(CLTheme.textPrimary)
                    Spacer()
                    Text("LIVE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(CLTheme.successGreen)
                        .clipShape(Capsule())
                }
                Text(patient.fullName)
                    .font(CLTheme.headlineFont)
                    .foregroundStyle(CLTheme.primaryNavy)
                Text(patient.phoneNumber.isEmpty ? "No phone on file" : patient.phoneNumber)
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
                            openChatWithActivePatient(patient)
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

                        if let url = phoneURL(for: patient.phoneNumber) {
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
                Text("\(patient.fullName) is selected, but there is no confirmed or in-progress booking.")
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
    }

    private func loadHomeData() async {
        isLoading = true
        let caregiverId = appState.authService.currentUser?.uid ?? ""
        async let bookingsTask = appState.firestoreService.fetchCaregiverBookings(for: caregiverId)
        async let activeSelectionTask = appState.firestoreService.fetchActivePatientForCaregiver(caregiverId: caregiverId)
        bookings = (try? await bookingsTask) ?? []
        activePatientSelection = try? await activeSelectionTask

        if let patientId = activePatientSelection?.patientId {
            activePatientProfile = try? await appState.firestoreService.fetchUser(patientId)
            if activePatientProfile == nil {
                // Selected patient no longer exists or is inaccessible.
                try? await appState.firestoreService.clearActivePatientForCaregiver(caregiverId: caregiverId)
                activePatientSelection = nil
            }
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
}

