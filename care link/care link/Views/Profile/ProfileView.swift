import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @State private var showSettings = false
    @State private var showEditProfile = false
    @State private var showMedicalRecords = false
    @State private var showFamilyMembers = false
    @State private var showPaymentMethods = false
    @State private var bookings: [Booking] = []
    @State private var connections: [Connection] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: CLTheme.spacingLG) {
                    profileHeader
                    quickStats
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
                profileMenuRow(icon: "person", title: "Edit Profile", subtitle: "Update your personal details") {
                    showEditProfile = true
                }
                profileMenuRow(icon: "person.3", title: "Family Members", subtitle: "Manage your care circle profiles") {
                    showFamilyMembers = true
                }
                profileMenuRow(icon: "creditcard", title: "Payment Methods", subtitle: "Manage cards and billing") {
                    showPaymentMethods = true
                }
                profileMenuRow(icon: "doc.text", title: "Medical Records", subtitle: "View your health records") {
                    showMedicalRecords = true
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
                profileMenuRow(icon: "questionmark.circle", title: "Help & Support", subtitle: "FAQs and contact support") {}
                profileMenuRow(icon: "lock.shield", title: "Privacy Policy", subtitle: "Terms and data usage") {}
            }
            .padding(.horizontal, CLTheme.spacingMD)
        }
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
