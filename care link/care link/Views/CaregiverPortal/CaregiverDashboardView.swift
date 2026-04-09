import SwiftUI
import FirebaseAuth

struct CaregiverDashboardView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = CaregiverPortalViewModel()
    @State private var selectedSection = 0

    @State private var connectedPatients: [CLUser] = []
    @State private var pendingConnections: [Connection] = []
    @State private var showMedicalRecords = false
    @State private var selectedPatientId = ""
    @State private var selectedPatientName = ""
    @State private var showChat = false
    @State private var chatConversation: ChatConversation?
    @State private var showEditProfile = false
    @State private var featuredBooking: Booking?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                CLNavigationBar(title: "Dashboard")

                ScrollView {
                    VStack(spacing: CLTheme.spacingLG) {
                        greetingSection
                        overviewCards

                        if let fb = featuredBooking {
                            activePatientHeroCard(fb)
                        }

                        if !pendingConnections.isEmpty {
                            pendingRequestsSection
                        }

                        patientsSection
                        appointmentsSection
                    }
                    .padding(.bottom, 100)
                }
            }
            .background(CLTheme.backgroundPrimary)
            .navigationDestination(isPresented: $showMedicalRecords) {
                MedicalRecordsView(patientId: selectedPatientId, patientName: selectedPatientName)
                    .environment(appState)
            }
            .navigationDestination(isPresented: $showChat) {
                if let conv = chatConversation {
                    ChatDetailView(conversation: conv)
                        .environment(appState)
                }
            }
            .sheet(isPresented: $showEditProfile) {
                CaregiverProfileEditView()
                    .environment(appState)
            }
            .task {
                await loadDashboardData()
            }
        }
    }

    // MARK: - Greeting

    private var greetingSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: CLTheme.spacingXS) {
                let hour = Calendar.current.component(.hour, from: Date())
                let greeting = hour < 12 ? "Good Morning" : (hour < 17 ? "Good Afternoon" : "Good Evening")
                Text(greeting)
                    .font(CLTheme.bodyFont)
                    .foregroundStyle(CLTheme.textSecondary)
                Text("Dr. \(appState.authService.userProfile?.fullName ?? "Caregiver")")
                    .font(CLTheme.titleFont)
                    .foregroundStyle(CLTheme.textPrimary)
            }
            Spacer()
            Button { showEditProfile = true } label: {
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(CLTheme.accentBlue)
            }
        }
        .padding(.horizontal, CLTheme.spacingMD)
    }

    // MARK: - Active patient (confirmed booking)

    private func activePatientHeroCard(_ booking: Booking) -> some View {
        VStack(alignment: .leading, spacing: CLTheme.spacingMD) {
            Text("Your patient")
                .font(CLTheme.title2Font)
                .foregroundStyle(CLTheme.textPrimary)
                .padding(.horizontal, CLTheme.spacingMD)

            VStack(alignment: .leading, spacing: CLTheme.spacingSM) {
                HStack(spacing: CLTheme.spacingMD) {
                    Circle()
                        .fill(CLTheme.tealAccent.opacity(0.2))
                        .frame(width: 56, height: 56)
                        .overlay {
                            Text(String((booking.patientName.isEmpty ? "PT" : booking.patientName).prefix(2)).uppercased())
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(CLTheme.tealAccent)
                        }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(booking.patientName.isEmpty ? "Patient" : booking.patientName)
                            .font(CLTheme.headlineFont)
                            .foregroundStyle(CLTheme.textPrimary)
                        Text(booking.date.formatted(date: .abbreviated, time: .omitted))
                            .font(CLTheme.captionFont)
                            .foregroundStyle(CLTheme.textSecondary)
                        Text("\(booking.startTime.formatted(date: .omitted, time: .shortened)) – \(booking.endTime.formatted(date: .omitted, time: .shortened))")
                            .font(CLTheme.captionFont)
                            .foregroundStyle(CLTheme.textTertiary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("$\(String(format: "%.0f", booking.totalCost))")
                            .font(CLTheme.titleFont)
                            .foregroundStyle(CLTheme.accentBlue)
                        Text(booking.paymentMethod.displayName)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(CLTheme.textTertiary)
                    }
                }

                HStack(spacing: CLTheme.spacingMD) {
                    Button {
                        openChatForBookingPatient(booking)
                    } label: {
                        Label("Message", systemImage: "message.fill")
                            .font(CLTheme.calloutFont)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundStyle(.white)
                            .background(CLTheme.primaryNavy)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    Button {
                        selectedPatientId = booking.userId
                        selectedPatientName = booking.patientName.isEmpty ? "Patient" : booking.patientName
                        showMedicalRecords = true
                    } label: {
                        Label("Records", systemImage: "doc.text.fill")
                            .font(CLTheme.calloutFont)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundStyle(CLTheme.primaryNavy)
                            .background(CLTheme.lightBlue)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(CLTheme.spacingMD)
            .background(CLTheme.cardBackground)
            .clipShape(CLTheme.continuousRect(cornerRadius: CLTheme.cornerRadiusXL))
            .shadow(color: CLTheme.shadowLight, radius: 10, y: 3)
            .padding(.horizontal, CLTheme.spacingMD)
        }
    }

    private func openChatForBookingPatient(_ booking: Booking) {
        Task {
            let caregiverId = appState.authService.currentUser?.uid ?? ""
            let caregiverName = appState.authService.userProfile?.fullName ?? "Caregiver"
            let patientName = booking.patientName.isEmpty ? "Patient" : booking.patientName
            let conv = try? await appState.chatService.getOrCreateConversation(
                userId: booking.userId,
                userName: patientName,
                caregiverId: caregiverId,
                caregiverName: caregiverName,
                caregiverSpecialty: ""
            )
            chatConversation = conv
            showChat = true
        }
    }

    // MARK: - Overview Cards

    private var overviewCards: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: CLTheme.spacingMD) {
                dashboardCard(
                    icon: "person.2.fill",
                    value: "\(connectedPatients.count)",
                    label: "Patients",
                    color: CLTheme.accentBlue
                )
                dashboardCard(
                    icon: "person.badge.clock",
                    value: "\(pendingConnections.count)",
                    label: "Pending",
                    color: CLTheme.warningOrange
                )
                dashboardCard(
                    icon: "calendar.badge.clock",
                    value: "\(viewModel.todayAppointmentCount)",
                    label: "Today",
                    color: CLTheme.tealAccent
                )
                dashboardCard(
                    icon: "dollarsign.circle.fill",
                    value: "$\(String(format: "%.0f", viewModel.totalEarnings))",
                    label: "Earnings",
                    color: CLTheme.successGreen
                )
            }
            .padding(.horizontal, CLTheme.spacingMD)
        }
    }

    private func dashboardCard(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: CLTheme.spacingSM) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(color)
            Text(value)
                .font(CLTheme.titleFont)
                .foregroundStyle(CLTheme.textPrimary)
            Text(label)
                .font(CLTheme.captionFont)
                .foregroundStyle(CLTheme.textSecondary)
        }
        .frame(width: 130, alignment: .leading)
        .padding(CLTheme.spacingMD)
        .background(CLTheme.cardBackground)
        .clipShape(CLTheme.continuousRect(cornerRadius: CLTheme.cornerRadiusLG))
        .shadow(color: CLTheme.shadowLight, radius: 6, y: 2)
    }

    // MARK: - Pending Requests

    private var pendingRequestsSection: some View {
        VStack(alignment: .leading, spacing: CLTheme.spacingMD) {
            HStack {
                Text("Connection Requests")
                    .font(CLTheme.title2Font)
                    .foregroundStyle(CLTheme.textPrimary)
                Spacer()
                Text("\(pendingConnections.count) new")
                    .font(CLTheme.captionFont)
                    .foregroundStyle(CLTheme.warningOrange)
            }
            .padding(.horizontal, CLTheme.spacingMD)

            ForEach(pendingConnections) { connection in
                CLCard {
                    VStack(spacing: CLTheme.spacingMD) {
                        HStack(spacing: CLTheme.spacingMD) {
                            Circle()
                                .fill(CLTheme.warningOrange.opacity(0.12))
                                .frame(width: 44, height: 44)
                                .overlay {
                                    Text(String(connection.userName.prefix(2)).uppercased())
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(CLTheme.warningOrange)
                                }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(connection.userName)
                                    .font(CLTheme.headlineFont)
                                    .foregroundStyle(CLTheme.textPrimary)
                                Text("Wants to connect")
                                    .font(CLTheme.captionFont)
                                    .foregroundStyle(CLTheme.textSecondary)
                            }
                            Spacer()
                        }

                        HStack(spacing: CLTheme.spacingMD) {
                            Button {
                                Task { await rejectConnection(connection) }
                            } label: {
                                Text("Decline")
                                    .font(CLTheme.calloutFont)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .foregroundStyle(CLTheme.errorRed)
                                    .background(CLTheme.errorRed.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: CLTheme.cornerRadiusSM))
                            }
                            Button {
                                Task { await approveConnection(connection) }
                            } label: {
                                Text("Approve")
                                    .font(CLTheme.calloutFont)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .foregroundStyle(.white)
                                    .background(CLTheme.successGreen)
                                    .clipShape(RoundedRectangle(cornerRadius: CLTheme.cornerRadiusSM))
                            }
                        }
                    }
                }
                .padding(.horizontal, CLTheme.spacingMD)
            }
        }
    }

    // MARK: - Patients

    private var patientsSection: some View {
        VStack(alignment: .leading, spacing: CLTheme.spacingMD) {
            Text("Your Patients")
                .font(CLTheme.title2Font)
                .foregroundStyle(CLTheme.textPrimary)
                .padding(.horizontal, CLTheme.spacingMD)

            if connectedPatients.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: CLTheme.spacingSM) {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .font(.system(size: 36))
                            .foregroundStyle(CLTheme.textTertiary)
                        Text("No patients yet")
                            .font(CLTheme.bodyFont)
                            .foregroundStyle(CLTheme.textSecondary)
                    }
                    .padding(.vertical, CLTheme.spacingLG)
                    Spacer()
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: CLTheme.spacingMD) {
                        ForEach(connectedPatients) { patient in
                            patientCard(patient)
                        }
                    }
                    .padding(.horizontal, CLTheme.spacingMD)
                }
            }
        }
    }

    private func patientCard(_ patient: CLUser) -> some View {
        VStack(spacing: CLTheme.spacingMD) {
            Circle()
                .fill(CLTheme.primaryNavy.opacity(0.12))
                .frame(width: 56, height: 56)
                .overlay {
                    Text(String(patient.fullName.prefix(2)).uppercased())
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(CLTheme.primaryNavy)
                }

            Text(patient.fullName)
                .font(CLTheme.calloutFont)
                .foregroundStyle(CLTheme.textPrimary)
                .lineLimit(1)

            HStack(spacing: CLTheme.spacingSM) {
                Button {
                    openChatWithPatient(patient)
                } label: {
                    Image(systemName: "message.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(CLTheme.accentBlue)
                        .frame(width: 36, height: 36)
                        .background(CLTheme.lightBlue)
                        .clipShape(Circle())
                }

                Button {
                    selectedPatientId = patient.id
                    selectedPatientName = patient.fullName
                    showMedicalRecords = true
                } label: {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(CLTheme.tealAccent)
                        .frame(width: 36, height: 36)
                        .background(CLTheme.tealAccent.opacity(0.12))
                        .clipShape(Circle())
                }
            }
        }
        .frame(width: 130)
        .padding(CLTheme.spacingMD)
        .background(CLTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: CLTheme.cornerRadiusLG))
        .shadow(color: CLTheme.shadowLight, radius: 4)
    }

    // MARK: - Appointments

    private var appointmentsSection: some View {
        VStack(alignment: .leading, spacing: CLTheme.spacingMD) {
            segmentedControl

            let appointments: [Booking] = {
                switch selectedSection {
                case 0: return viewModel.pendingRequests
                case 1: return viewModel.upcomingAppointments
                case 2: return viewModel.completedAppointments
                default: return []
                }
            }()

            if appointments.isEmpty {
                emptyAppointments
            } else {
                LazyVStack(spacing: CLTheme.spacingMD) {
                    ForEach(appointments) { booking in
                        appointmentCard(booking)
                    }
                }
                .padding(.horizontal, CLTheme.spacingMD)
            }
        }
    }

    private var segmentedControl: some View {
        HStack(spacing: 0) {
            segmentButton("Pending", index: 0, count: viewModel.pendingRequests.count)
            segmentButton("Upcoming", index: 1, count: viewModel.upcomingAppointments.count)
            segmentButton("Done", index: 2, count: viewModel.completedAppointments.count)
        }
        .padding(5)
        .background(CLTheme.backgroundSecondary)
        .clipShape(Capsule())
        .padding(.horizontal, CLTheme.spacingMD)
    }

    private func segmentButton(_ title: String, index: Int, count: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) { selectedSection = index }
        } label: {
            HStack(spacing: 4) {
                Text(title)
                    .font(CLTheme.calloutFont)
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(selectedSection == index ? CLTheme.accentBlue : CLTheme.textTertiary)
                        .clipShape(Capsule())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .foregroundStyle(selectedSection == index ? .white : CLTheme.textSecondary)
            .background(selectedSection == index ? CLTheme.primaryNavy : .clear)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func appointmentCard(_ booking: Booking) -> some View {
        CLCard {
            VStack(spacing: CLTheme.spacingMD) {
                HStack {
                    VStack(alignment: .leading, spacing: CLTheme.spacingXS) {
                        Text(booking.patientName.isEmpty ? "Patient" : booking.patientName)
                            .font(CLTheme.headlineFont)
                            .foregroundStyle(CLTheme.textPrimary)
                        Text(booking.date.formatted(date: .abbreviated, time: .omitted))
                            .font(CLTheme.captionFont)
                            .foregroundStyle(CLTheme.textSecondary)
                    }
                    Spacer()
                    Text(booking.status.rawValue)
                        .font(CLTheme.captionFont)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(hex: booking.status.color))
                        .clipShape(Capsule())
                }

                HStack(spacing: CLTheme.spacingMD) {
                    Label(booking.startTime.formatted(date: .omitted, time: .shortened), systemImage: "clock")
                        .font(CLTheme.captionFont)
                        .foregroundStyle(CLTheme.textSecondary)
                    Spacer()
                    Text("$\(String(format: "%.2f", booking.totalCost))")
                        .font(CLTheme.headlineFont)
                        .foregroundStyle(CLTheme.accentBlue)
                }

                if booking.status.needsCaregiverAction {
                    HStack(spacing: CLTheme.spacingMD) {
                        Button {
                            Task { await viewModel.rejectBooking(bookingId: booking.id, firestoreService: appState.firestoreService) }
                        } label: {
                            Text("Decline")
                                .font(CLTheme.calloutFont)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .foregroundStyle(CLTheme.errorRed)
                                .background(CLTheme.errorRed.opacity(0.1))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        Button {
                            Task { await viewModel.acceptBooking(bookingId: booking.id, firestoreService: appState.firestoreService) }
                        } label: {
                            Text("Accept")
                                .font(CLTheme.calloutFont)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .foregroundStyle(.white)
                                .background(CLTheme.successGreen)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var emptyAppointments: some View {
        VStack(spacing: CLTheme.spacingMD) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(CLTheme.textTertiary)
            Text("No appointments")
                .font(CLTheme.headlineFont)
                .foregroundStyle(CLTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, CLTheme.spacingXL)
    }

    // MARK: - Data

    private func loadDashboardData() async {
        let caregiverId = appState.authService.currentUser?.uid ?? ""
        async let appointmentsTask: () = viewModel.loadAppointments(caregiverId: caregiverId, firestoreService: appState.firestoreService)
        async let patientsTask: () = {
            self.connectedPatients = (try? await appState.firestoreService.fetchConnectedPatients(caregiverId: caregiverId)) ?? []
        }()
        async let pendingTask: () = {
            self.pendingConnections = (try? await appState.firestoreService.fetchPendingConnectionsForCaregiver(caregiverId)) ?? []
        }()
        _ = await (appointmentsTask, patientsTask, pendingTask)
        featuredBooking = viewModel.upcomingAppointments.min(by: { $0.date == $1.date ? $0.startTime < $1.startTime : $0.date < $1.date })
    }

    private func approveConnection(_ connection: Connection) async {
        try? await appState.firestoreService.updateConnectionStatus(connectionId: connection.id, status: .approved)
        pendingConnections.removeAll { $0.id == connection.id }
        if let user = try? await appState.firestoreService.fetchUser(connection.userId) {
            connectedPatients.append(user)
        }
    }

    private func rejectConnection(_ connection: Connection) async {
        try? await appState.firestoreService.updateConnectionStatus(connectionId: connection.id, status: .rejected)
        pendingConnections.removeAll { $0.id == connection.id }
    }

    private func openChatWithPatient(_ patient: CLUser) {
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
}

#Preview {
    CaregiverDashboardView()
        .environment(AppState())
}
