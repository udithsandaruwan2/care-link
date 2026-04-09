import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @State private var showSettings = false
    @State private var showEditProfile = false
    @State private var showMedicalRecords = false
    @State private var bookings: [Booking] = []
    @State private var connections: [Connection] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: CLTheme.spacingLG) {
                    profileHeader
                    quickActions
                    connectionSection
                    bookingHistorySection
                }
                .padding(.bottom, 100)
            }
            .background(CLTheme.backgroundPrimary)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(CLTheme.textPrimary)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environment(appState)
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileView()
                    .environment(appState)
            }
            .navigationDestination(isPresented: $showMedicalRecords) {
                let userId = appState.authService.currentUser?.uid ?? ""
                let userName = appState.authService.userProfile?.fullName ?? "Patient"
                MedicalRecordsView(patientId: userId, patientName: userName)
                    .environment(appState)
            }
            .task {
                let userId = appState.authService.currentUser?.uid ?? ""
                async let bookingsTask: () = {
                    self.bookings = (try? await appState.firestoreService.fetchBookings(for: userId)) ?? []
                }()
                async let connectionsTask: () = {
                    self.connections = (try? await appState.firestoreService.fetchConnectionsForUser(userId)) ?? []
                }()
                _ = await (bookingsTask, connectionsTask)
            }
        }
    }

    private var profileHeader: some View {
        VStack(spacing: CLTheme.spacingMD) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(CLTheme.primaryNavy.opacity(0.12))
                    .frame(width: 90, height: 90)
                    .overlay {
                        Text(String((appState.authService.userProfile?.fullName ?? "U").prefix(2)).uppercased())
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(CLTheme.primaryNavy)
                    }

                Button {
                    showEditProfile = true
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(CLTheme.accentBlue)
                        .background(Circle().fill(.white).frame(width: 24, height: 24))
                }
            }

            VStack(spacing: CLTheme.spacingXS) {
                Text(appState.authService.userProfile?.fullName ?? "User")
                    .font(CLTheme.titleFont)
                    .foregroundStyle(CLTheme.textPrimary)

                Text(appState.authService.userProfile?.email ?? appState.authService.currentUser?.email ?? "")
                    .font(CLTheme.bodyFont)
                    .foregroundStyle(CLTheme.textSecondary)

                CLBadge(
                    title: appState.currentUserRole == .caregiver ? "Caregiver" : "Patient",
                    style: .filled
                )
            }
        }
        .padding(.top, CLTheme.spacingLG)
    }

    private var quickActions: some View {
        HStack(spacing: CLTheme.spacingMD) {
            quickActionButton(icon: "calendar", title: "Bookings", count: bookings.count) {}
            quickActionButton(icon: "link.circle", title: "Connections", count: connections.filter { $0.status == .approved }.count) {}
            quickActionButton(icon: "doc.text", title: "Records", count: 0) {
                showMedicalRecords = true
            }
        }
        .padding(.horizontal, CLTheme.spacingMD)
    }

    private func quickActionButton(icon: String, title: String, count: Int, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: CLTheme.spacingSM) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundStyle(CLTheme.accentBlue)
                        .frame(width: 50, height: 50)
                        .background(CLTheme.lightBlue)
                        .clipShape(Circle())

                    if count > 0 {
                        Text("\(count)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 18, height: 18)
                            .background(CLTheme.errorRed)
                            .clipShape(Circle())
                    }
                }

                Text(title)
                    .font(CLTheme.captionFont)
                    .foregroundStyle(CLTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, CLTheme.spacingMD)
            .background(CLTheme.cardBackground)
            .clipShape(CLTheme.continuousRect(cornerRadius: CLTheme.cornerRadiusLG))
            .shadow(color: CLTheme.shadowLight, radius: 8, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Connections

    @ViewBuilder
    private var connectionSection: some View {
        let activeConnections = connections.filter { $0.status == .approved }
        if !activeConnections.isEmpty {
            VStack(alignment: .leading, spacing: CLTheme.spacingMD) {
                Text("Connected Caregivers")
                    .font(CLTheme.title2Font)
                    .foregroundStyle(CLTheme.textPrimary)
                    .padding(.horizontal, CLTheme.spacingMD)

                ForEach(activeConnections) { connection in
                    CLCard {
                        HStack(spacing: CLTheme.spacingMD) {
                            Circle()
                                .fill(CLTheme.successGreen.opacity(0.12))
                                .frame(width: 44, height: 44)
                                .overlay {
                                    Text(String(connection.caregiverName.prefix(2)).uppercased())
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(CLTheme.successGreen)
                                }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(connection.caregiverName)
                                    .font(CLTheme.headlineFont)
                                    .foregroundStyle(CLTheme.textPrimary)
                                Text(connection.caregiverSpecialty)
                                    .font(CLTheme.captionFont)
                                    .foregroundStyle(CLTheme.textSecondary)
                            }

                            Spacer()

                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(CLTheme.successGreen)
                        }
                    }
                    .padding(.horizontal, CLTheme.spacingMD)
                }
            }
        }
    }

    // MARK: - Booking History

    private var bookingHistorySection: some View {
        VStack(alignment: .leading, spacing: CLTheme.spacingMD) {
            HStack {
                Text("Recent Bookings")
                    .font(CLTheme.title2Font)
                    .foregroundStyle(CLTheme.textPrimary)
                Spacer()
            }
            .padding(.horizontal, CLTheme.spacingMD)

            if bookings.isEmpty {
                VStack(spacing: CLTheme.spacingMD) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 40))
                        .foregroundStyle(CLTheme.textTertiary)
                    Text("No bookings yet")
                        .font(CLTheme.headlineFont)
                        .foregroundStyle(CLTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, CLTheme.spacingXL)
            } else {
                ForEach(bookings.prefix(5)) { booking in
                    bookingRow(booking)
                }
            }
        }
    }

    private func bookingRow(_ booking: Booking) -> some View {
        CLCard {
            HStack(spacing: CLTheme.spacingMD) {
                Circle()
                    .fill(CLTheme.primaryNavy.opacity(0.12))
                    .frame(width: 44, height: 44)
                    .overlay {
                        Text(String(booking.caregiverName.prefix(2)).uppercased())
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(CLTheme.primaryNavy)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(booking.caregiverName)
                        .font(CLTheme.headlineFont)
                        .foregroundStyle(CLTheme.textPrimary)
                    Text(booking.date.formatted(date: .abbreviated, time: .omitted))
                        .font(CLTheme.captionFont)
                        .foregroundStyle(CLTheme.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(booking.status.rawValue)
                        .font(CLTheme.captionFont)
                        .foregroundStyle(Color(hex: booking.status.color))
                    Text("$\(String(format: "%.2f", booking.totalCost))")
                        .font(CLTheme.calloutFont)
                        .foregroundStyle(CLTheme.textPrimary)
                }
            }
        }
        .padding(.horizontal, CLTheme.spacingMD)
    }
}

#Preview {
    ProfileView()
        .environment(AppState())
}
