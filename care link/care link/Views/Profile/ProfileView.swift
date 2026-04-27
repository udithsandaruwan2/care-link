import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @State private var showSettings = false
    @State private var showEditProfile = false
    @State private var showMedicalRecords = false
    @State private var showFamilyMembers = false
    @State private var showPaymentMethods = false
    @State private var showMyCareHub = false
    @State private var showSupportCenter = false
    @State private var showPrivacyPolicy = false
    @State private var bookings: [Booking] = []
    @State private var connections: [Connection] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: CLTheme.spacingLG) {
                    profileHeader
                    quickStats
                    if appState.currentUserRole == .user {
                        healthSection
                    }
                    accountSection
                    supportSection
                    signOutSection
                }
                .padding(.bottom, 100)
            }
            .background(CLTheme.backgroundPrimary)
            .navigationTitle("CareLink")
            .navigationBarTitleDisplayMode(.large)
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
            .navigationDestination(isPresented: $showFamilyMembers) {
                FamilyMembersView()
                    .environment(appState)
            }
            .navigationDestination(isPresented: $showPaymentMethods) {
                PaymentMethodsView()
                    .environment(appState)
            }
            .navigationDestination(isPresented: $showMyCareHub) {
                MyCareHubView()
                    .environment(appState)
            }
            .navigationDestination(isPresented: $showMedicalRecords) {
                let userId = appState.authService.currentUser?.uid ?? ""
                let userName = appState.authService.userProfile?.fullName ?? "Patient"
                MedicalRecordsView(patientId: userId, patientName: userName)
                    .environment(appState)
            }
            .navigationDestination(isPresented: $showSupportCenter) {
                SupportCenterView()
            }
            .navigationDestination(isPresented: $showPrivacyPolicy) {
                PrivacyPolicyView()
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
                if UserDefaults.standard.bool(forKey: "carelink.healthKitSyncEnabled") {
                    await appState.healthKitService.refreshAuthorizationStatus()
                    await appState.healthKitService.refreshMetrics()
                }
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

    private var quickStats: some View {
        HStack(spacing: CLTheme.spacingMD) {
            statTile(
                title: "ACTIVE",
                subtitle: "CONNECTIONS",
                value: String(format: "%02d", connections.filter { $0.status == .approved }.count),
                highlighted: false
            )
            statTile(
                title: "HEALTH",
                subtitle: "SCORE",
                value: "\(min(99, 70 + bookings.count * 2))%",
                highlighted: true
            )
        }
        .padding(.horizontal, CLTheme.spacingMD)
    }

    private func statTile(title: String, subtitle: String, value: String, highlighted: Bool) -> some View {
        VStack(alignment: .leading, spacing: CLTheme.spacingSM) {
            Text(title)
                .font(CLTheme.smallFont)
                .tracking(1)
                .foregroundStyle(highlighted ? .white.opacity(0.8) : CLTheme.tealAccent)
            Text(subtitle)
                .font(CLTheme.smallFont)
                .tracking(1)
                .foregroundStyle(highlighted ? .white.opacity(0.8) : CLTheme.tealAccent)
            Text(value)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(highlighted ? .white : CLTheme.textPrimary)
            if highlighted {
                Capsule()
                    .fill(.white.opacity(0.8))
                    .frame(height: 3)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CLTheme.spacingMD)
        .background(highlighted ? AnyShapeStyle(CLTheme.gradientBlue) : AnyShapeStyle(CLTheme.cardBackground))
        .clipShape(CLTheme.continuousRect(cornerRadius: CLTheme.cornerRadiusLG))
        .shadow(color: CLTheme.shadowLight, radius: 8, y: 3)
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: CLTheme.spacingMD) {
            Text("Account Settings")
                .font(CLTheme.title2Font)
                .foregroundStyle(CLTheme.textPrimary)
                .padding(.horizontal, CLTheme.spacingMD)

            VStack(spacing: CLTheme.spacingSM) {
                if appState.currentUserRole == .user {
                    profileMenuRow(icon: "heart.text.square", title: "My care hub", subtitle: "Active requests, visits, and history") {
                        showMyCareHub = true
                    }
                }
                profileMenuRow(icon: "person", title: "Edit Profile", subtitle: "Update your personal details") {
                    showEditProfile = true
                }
                if appState.currentUserRole == .user {
                    profileMenuRow(icon: "person.3", title: "Family Members", subtitle: "Manage your care circle profiles") {
                        showFamilyMembers = true
                    }
                }
                profileMenuRow(icon: "creditcard", title: "Payment Methods", subtitle: "Manage cards and billing") {
                    showPaymentMethods = true
                }
                if appState.currentUserRole == .user {
                    profileMenuRow(icon: "doc.text", title: "Medical Records", subtitle: "View your health records") {
                        showMedicalRecords = true
                    }
                }
            }
            .padding(.horizontal, CLTheme.spacingMD)
        }
    }

    private var supportSection: some View {
        VStack(alignment: .leading, spacing: CLTheme.spacingMD) {
            Text("Support")
                .font(CLTheme.title2Font)
                .foregroundStyle(CLTheme.textPrimary)
                .padding(.horizontal, CLTheme.spacingMD)

            VStack(spacing: CLTheme.spacingSM) {
                profileMenuRow(icon: "questionmark.circle", title: "Help & Support", subtitle: "Contact support and browse Q&A") {
                    showSupportCenter = true
                }
                profileMenuRow(icon: "lock.shield", title: "Privacy Policy", subtitle: "Terms and data usage") {
                    showPrivacyPolicy = true
                }
            }
            .padding(.horizontal, CLTheme.spacingMD)
        }
    }

    private var healthSection: some View {
        VStack(alignment: .leading, spacing: CLTheme.spacingMD) {
            HStack {
                Text("Health Monitor")
                    .font(CLTheme.title2Font)
                    .foregroundStyle(CLTheme.textPrimary)
                Spacer()
                Text(appState.healthKitService.isAuthorized ? "Connected" : "Not Connected")
                    .font(CLTheme.captionFont)
                    .foregroundStyle(appState.healthKitService.isAuthorized ? CLTheme.successGreen : CLTheme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((appState.healthKitService.isAuthorized ? CLTheme.successGreen : CLTheme.textTertiary).opacity(0.12))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, CLTheme.spacingMD)

            HStack(spacing: CLTheme.spacingMD) {
                healthTile(
                    title: "Heart",
                    value: appState.healthKitService.metrics.heartRateBPM.map(String.init) ?? "--",
                    unit: "BPM",
                    icon: "heart.fill",
                    color: CLTheme.errorRed
                )
                healthTile(
                    title: "SpO2",
                    value: appState.healthKitService.metrics.oxygenPercent.map(String.init) ?? "--",
                    unit: "%",
                    icon: "lungs.fill",
                    color: CLTheme.tealAccent
                )
                healthTile(
                    title: "Breath",
                    value: appState.healthKitService.metrics.respiratoryRate.map(String.init) ?? "--",
                    unit: "RPM",
                    icon: "wind",
                    color: CLTheme.accentBlue
                )
            }
            .padding(.horizontal, CLTheme.spacingMD)
        }
    }

    private func healthTile(title: String, value: String, unit: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(title)
                .font(CLTheme.captionFont)
                .foregroundStyle(CLTheme.textSecondary)
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(CLTheme.textPrimary)
                Text(unit)
                    .font(CLTheme.smallFont)
                    .foregroundStyle(CLTheme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CLTheme.spacingSM)
        .background(CLTheme.cardBackground)
        .clipShape(CLTheme.continuousRect(cornerRadius: CLTheme.cornerRadiusMD))
    }

    private var signOutSection: some View {
        VStack(spacing: CLTheme.spacingMD) {
            Button {
                appState.signOut()
            } label: {
                HStack(spacing: CLTheme.spacingMD) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundStyle(CLTheme.errorRed)
                    Text("Sign Out")
                        .font(CLTheme.headlineFont)
                        .foregroundStyle(CLTheme.errorRed)
                    Spacer()
                }
                .padding(CLTheme.spacingMD)
                .background(CLTheme.errorRed.opacity(0.08))
                .clipShape(CLTheme.continuousRect(cornerRadius: CLTheme.cornerRadiusLG))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, CLTheme.spacingMD)

            Text("CARELINK VERSION 2.4.0")
                .font(CLTheme.captionFont)
                .foregroundStyle(CLTheme.textTertiary)
        }
    }

    private func profileMenuRow(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: CLTheme.spacingSM) {
                HStack(spacing: CLTheme.spacingMD) {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(CLTheme.primaryNavy)
                        .frame(width: 34, height: 34)
                        .background(CLTheme.backgroundSecondary)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(CLTheme.headlineFont)
                            .foregroundStyle(CLTheme.textPrimary)
                        Text(subtitle)
                            .font(CLTheme.captionFont)
                            .foregroundStyle(CLTheme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(CLTheme.textTertiary)
                }
            }
            .padding(CLTheme.spacingMD)
            .background(CLTheme.cardBackground)
            .clipShape(CLTheme.continuousRect(cornerRadius: CLTheme.cornerRadiusLG))
            .shadow(color: CLTheme.shadowLight, radius: 8, y: 2)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ProfileView()
        .environment(AppState())
}
