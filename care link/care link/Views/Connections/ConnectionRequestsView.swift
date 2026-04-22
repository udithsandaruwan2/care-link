import SwiftUI
import FirebaseAuth

struct ConnectionRequestsView: View {
    @Environment(AppState.self) private var appState
    @State private var pendingConnections: [Connection] = []
    @State private var activeConnections: [Connection] = []
    @State private var isLoading = true
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            segmentedControl

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                TabView(selection: $selectedTab) {
                    pendingList.tag(0)
                    activeList.tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
        .background(CLTheme.backgroundPrimary)
        .task {
            await loadConnections()
        }
    }

    private var segmentedControl: some View {
        HStack(spacing: 0) {
            segmentButton("Pending", index: 0, count: pendingConnections.count)
            segmentButton("Connected", index: 1, count: activeConnections.count)
        }
        .padding(5)
        .background(CLTheme.backgroundSecondary)
        .clipShape(Capsule())
        .padding(.horizontal, CLTheme.spacingMD)
        .padding(.vertical, CLTheme.spacingSM)
    }

    private func segmentButton(_ title: String, index: Int, count: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                selectedTab = index
            }
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
                        .background(selectedTab == index ? CLTheme.accentBlue : CLTheme.textTertiary)
                        .clipShape(Capsule())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .foregroundStyle(selectedTab == index ? .white : CLTheme.textSecondary)
            .background(selectedTab == index ? CLTheme.primaryNavy : .clear)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Pending

    private var pendingList: some View {
        Group {
            if pendingConnections.isEmpty {
                VStack(spacing: CLTheme.spacingMD) {
                    Spacer()
                    Image(systemName: "person.badge.clock")
                        .font(.system(size: 48))
                        .foregroundStyle(CLTheme.textTertiary)
                    Text("No pending requests")
                        .font(CLTheme.headlineFont)
                        .foregroundStyle(CLTheme.textSecondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: CLTheme.spacingMD) {
                        ForEach(pendingConnections) { connection in
                            pendingCard(connection)
                        }
                    }
                    .padding(.horizontal, CLTheme.spacingMD)
                    .padding(.bottom, 100)
                }
            }
        }
    }

    private func pendingCard(_ connection: Connection) -> some View {
        CLCard {
            VStack(spacing: CLTheme.spacingMD) {
                HStack(spacing: CLTheme.spacingMD) {
                    Circle()
                        .fill(CLTheme.primaryNavy.opacity(0.12))
                        .frame(width: 50, height: 50)
                        .overlay {
                            Text(String(connection.userName.prefix(2)).uppercased())
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(CLTheme.primaryNavy)
                        }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(connection.userName)
                            .font(CLTheme.headlineFont)
                            .foregroundStyle(CLTheme.textPrimary)
                        Text("Requested \(connection.createdAt, style: .relative) ago")
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
                            .padding(.vertical, 12)
                            .foregroundStyle(CLTheme.errorRed)
                            .background(CLTheme.errorRed.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        Task { await approveConnection(connection) }
                    } label: {
                        Text("Approve")
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

    // MARK: - Active

    private var activeList: some View {
        Group {
            if activeConnections.isEmpty {
                VStack(spacing: CLTheme.spacingMD) {
                    Spacer()
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(CLTheme.textTertiary)
                    Text("No connected patients")
                        .font(CLTheme.headlineFont)
                        .foregroundStyle(CLTheme.textSecondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: CLTheme.spacingMD) {
                        ForEach(activeConnections) { connection in
                            activeCard(connection)
                        }
                    }
                    .padding(.horizontal, CLTheme.spacingMD)
                    .padding(.bottom, 100)
                }
            }
        }
    }

    private func activeCard(_ connection: Connection) -> some View {
        CLCard {
            HStack(spacing: CLTheme.spacingMD) {
                Circle()
                    .fill(CLTheme.successGreen.opacity(0.12))
                    .frame(width: 50, height: 50)
                    .overlay {
                        Text(String(connection.userName.prefix(2)).uppercased())
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(CLTheme.successGreen)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(connection.userName)
                        .font(CLTheme.headlineFont)
                        .foregroundStyle(CLTheme.textPrimary)
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(CLTheme.successGreen)
                        Text("Connected")
                            .font(CLTheme.captionFont)
                            .foregroundStyle(CLTheme.successGreen)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(CLTheme.textTertiary)
            }
        }
    }

    // MARK: - Actions

    private func loadConnections() async {
        let caregiverId = appState.authService.currentUser?.uid ?? ""
        do {
            async let pending = appState.firestoreService.fetchPendingConnectionsForCaregiver(caregiverId)
            async let active = appState.firestoreService.fetchActiveConnectionsForCaregiver(caregiverId)
            pendingConnections = try await pending
            activeConnections = try await active
        } catch {}
        isLoading = false
    }

    private func approveConnection(_ connection: Connection) async {
        do {
            let caregiverId = appState.authService.currentUser?.uid ?? ""
            try await appState.firestoreService.updateConnectionStatus(
                connectionId: connection.id, status: .approved
            )
            try? await appState.firestoreService.createNotification(
                CLNotification(
                    id: UUID().uuidString,
                    userId: connection.userId,
                    senderUserId: caregiverId,
                    title: "Connection approved",
                    message: "\(connection.caregiverName) approved your connection request.",
                    type: .connectionApproved,
                    isRead: false,
                    createdAt: Date()
                )
            )
            pendingConnections.removeAll { $0.id == connection.id }
            var approved = connection
            approved.status = .approved
            activeConnections.append(approved)
        } catch {}
    }

    private func rejectConnection(_ connection: Connection) async {
        do {
            let caregiverId = appState.authService.currentUser?.uid ?? ""
            try await appState.firestoreService.updateConnectionStatus(
                connectionId: connection.id, status: .rejected
            )
            try? await appState.firestoreService.createNotification(
                CLNotification(
                    id: UUID().uuidString,
                    userId: connection.userId,
                    senderUserId: caregiverId,
                    title: "Connection declined",
                    message: "\(connection.caregiverName) declined your request.",
                    type: .connectionRequest,
                    isRead: false,
                    createdAt: Date()
                )
            )
            pendingConnections.removeAll { $0.id == connection.id }
        } catch {}
    }
}
