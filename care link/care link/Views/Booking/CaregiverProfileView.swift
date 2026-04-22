import SwiftUI
import FirebaseAuth

struct CaregiverProfileView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let caregiver: Caregiver
    @State private var reviews: [Review] = []
    @State private var showBooking = false
    @State private var existingConnection: Connection?
    @State private var activePatientBooking: Booking?
    @State private var isRequestingConnection = false
    @State private var showChat = false
    @State private var chatConversation: ChatConversation?

    var body: some View {
        ScrollView {
            VStack(spacing: CLTheme.spacingLG) {
                profileHeader
                connectionStatusBanner
                statsRow
                experienceSection
                skillsSection
                reviewsSection
            }
            .padding(.bottom, CLTheme.spacingMD)
        }
        .background(CLTheme.backgroundPrimary)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                Divider()
                bottomBar
            }
            .background(.ultraThinMaterial)
        }
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(CLTheme.textPrimary)
                }
            }
            ToolbarItem(placement: .principal) {
                Text("Caregiver Profile")
                    .font(CLTheme.title2Font)
            }
        }
        .navigationDestination(isPresented: $showBooking) {
            BookingDetailsView(caregiver: caregiver)
                .environment(appState)
        }
        .navigationDestination(isPresented: $showChat) {
            if let conv = chatConversation {
                ChatDetailView(conversation: conv)
                    .environment(appState)
            }
        }
        .task {
            await loadData()
        }
    }

    private func loadData() async {
        let userId = appState.authService.currentUser?.uid ?? ""
        async let reviewsTask: () = {
            self.reviews = (try? await appState.firestoreService.fetchReviews(for: caregiver.id)) ?? []
        }()
        async let connectionTask: () = {
            self.existingConnection = try? await appState.firestoreService.checkExistingConnection(
                userId: userId, caregiverId: caregiver.id
            )
        }()
        async let bookingTask: () = {
            let bookings = (try? await appState.firestoreService.fetchBookings(for: userId)) ?? []
            self.activePatientBooking = bookings.first { $0.status.blocksNewBookingRequest }
        }()
        _ = await (reviewsTask, connectionTask, bookingTask)
    }

    // MARK: - Connection Status Banner

    @ViewBuilder
    private var connectionStatusBanner: some View {
        if let connection = existingConnection {
            HStack(spacing: CLTheme.spacingSM) {
                Image(systemName: connection.status.iconName)
                    .foregroundStyle(Color(hex: connection.status.colorHex))
                Text("Connection: \(connection.status.displayName)")
                    .font(CLTheme.calloutFont)
                    .foregroundStyle(Color(hex: connection.status.colorHex))
                Spacer()
            }
            .padding(CLTheme.spacingMD)
            .background(Color(hex: connection.status.colorHex).opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: CLTheme.cornerRadiusMD))
            .padding(.horizontal, CLTheme.spacingMD)
        }
    }

    private var profileHeader: some View {
        VStack(spacing: CLTheme.spacingMD) {
            CaregiverAvatar(size: 100, imageURL: caregiver.imageURL, showVerified: caregiver.isVerified)

            VStack(spacing: CLTheme.spacingXS) {
                Text("\(caregiver.name), \(caregiver.title)")
                    .font(CLTheme.titleFont)
                    .foregroundStyle(CLTheme.textPrimary)

                Text("Specialized \(caregiver.specialty)")
                    .font(CLTheme.bodyFont)
                    .foregroundStyle(CLTheme.textSecondary)

                HStack(spacing: CLTheme.spacingSM) {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(CLTheme.starYellow)
                        Text(String(format: "%.1f", caregiver.rating))
                            .font(CLTheme.calloutFont)
                    }
                    Text("•")
                        .foregroundStyle(CLTheme.textTertiary)
                    Text("\(caregiver.reviewCount)+ Bookings")
                        .font(CLTheme.calloutFont)
                        .foregroundStyle(CLTheme.textSecondary)
                }
            }
        }
        .padding(.top, CLTheme.spacingMD)
    }

    private var statsRow: some View {
        HStack {
            CLStatBadge(
                icon: "briefcase.fill",
                value: "\(caregiver.experienceYears) Years",
                label: "Experience"
            )

            Divider()
                .frame(height: 40)

            CLStatBadge(
                icon: "location.fill",
                value: String(format: "%.1f mi", caregiver.distance),
                label: "Distance"
            )
        }
        .padding(.vertical, CLTheme.spacingMD)
        .padding(.horizontal, CLTheme.spacingLG)
        .background(CLTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: CLTheme.cornerRadiusLG))
        .shadow(color: CLTheme.shadowLight, radius: 4, x: 0, y: 1)
        .padding(.horizontal, CLTheme.spacingMD)
    }

    private var experienceSection: some View {
        VStack(alignment: .leading, spacing: CLTheme.spacingMD) {
            Text("Experience")
                .font(CLTheme.title2Font)
                .foregroundStyle(CLTheme.textPrimary)

            CLCard {
                VStack(alignment: .leading, spacing: CLTheme.spacingMD) {
                    Text(caregiver.bio)
                        .font(CLTheme.bodyFont)
                        .foregroundStyle(CLTheme.textSecondary)
                        .lineSpacing(4)

                    FlowLayout(spacing: 8) {
                        ForEach(caregiver.certifications, id: \.self) { cert in
                            CLBadge(
                                title: cert,
                                style: caregiver.certifications.firstIndex(of: cert) == 0 ? .filled : .outlined
                            )
                        }
                    }
                }
            }
        }
        .padding(.horizontal, CLTheme.spacingMD)
    }

    private var skillsSection: some View {
        VStack(alignment: .leading, spacing: CLTheme.spacingMD) {
            Text("Skills")
                .font(CLTheme.title2Font)
                .foregroundStyle(CLTheme.textPrimary)

            VStack(spacing: CLTheme.spacingSM) {
                ForEach(caregiver.skills, id: \.self) { skill in
                    HStack(spacing: CLTheme.spacingMD) {
                        Image(systemName: skillIcon(for: skill))
                            .font(.system(size: 16))
                            .foregroundStyle(CLTheme.accentBlue)
                            .frame(width: 24)
                        Text(skill)
                            .font(CLTheme.bodyFont)
                            .foregroundStyle(CLTheme.textPrimary)
                        Spacer()
                    }
                    .padding(.vertical, CLTheme.spacingXS)
                }
            }
        }
        .padding(.horizontal, CLTheme.spacingMD)
    }

    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: CLTheme.spacingMD) {
            HStack {
                Text("Reviews")
                    .font(CLTheme.title2Font)
                    .foregroundStyle(CLTheme.textPrimary)
                Spacer()
                if reviews.count > 2 {
                    Button("View All") {}
                        .font(CLTheme.calloutFont)
                        .foregroundStyle(CLTheme.accentBlue)
                }
            }

            if reviews.isEmpty {
                HStack {
                    Spacer()
                    Text("No reviews yet")
                        .font(CLTheme.bodyFont)
                        .foregroundStyle(CLTheme.textTertiary)
                    Spacer()
                }
                .padding(.vertical, CLTheme.spacingLG)
            } else {
                ForEach(reviews.prefix(2)) { review in
                    reviewCard(review)
                }
            }
        }
        .padding(.horizontal, CLTheme.spacingMD)
    }

    private func reviewCard(_ review: Review) -> some View {
        CLCard {
            VStack(alignment: .leading, spacing: CLTheme.spacingSM) {
                HStack {
                    Circle()
                        .fill(CLTheme.primaryNavy.opacity(0.15))
                        .frame(width: 36, height: 36)
                        .overlay {
                            Text(String(review.userName.prefix(2)).uppercased())
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(CLTheme.primaryNavy)
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(review.userName)
                            .font(CLTheme.calloutFont)
                            .foregroundStyle(CLTheme.textPrimary)
                        Text(review.createdAt, style: .relative)
                            .font(CLTheme.captionFont)
                            .foregroundStyle(CLTheme.textTertiary)
                    }

                    Spacer()

                    HStack(spacing: 2) {
                        ForEach(0..<5, id: \.self) { i in
                            Image(systemName: i < Int(review.rating) ? "star.fill" : "star")
                                .font(.system(size: 10))
                                .foregroundStyle(CLTheme.starYellow)
                        }
                    }
                }

                Text("\"\(review.comment)\"")
                    .font(CLTheme.bodyFont)
                    .foregroundStyle(CLTheme.textSecondary)
                    .italic()
                    .lineSpacing(2)
            }
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: CLTheme.spacingMD) {
            if appState.currentUserRole == .user {
                HStack(spacing: CLTheme.spacingMD) {
                    Button {
                        openChat()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "message.fill")
                            Text("Chat")
                                .font(CLTheme.headlineFont)
                        }
                        .foregroundStyle(CLTheme.primaryNavy)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(CLTheme.lightBlue)
                        .clipShape(RoundedRectangle(cornerRadius: CLTheme.cornerRadiusMD))
                    }

                    Button {
                        showBooking = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar.badge.plus")
                            Text("Book")
                                .font(CLTheme.headlineFont)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(CLTheme.gradientBlue)
                        .clipShape(RoundedRectangle(cornerRadius: CLTheme.cornerRadiusMD))
                    }
                    .disabled(activePatientBooking != nil)
                }

                if let active = activePatientBooking {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(CLTheme.warningOrange)
                        Text("You already have an active request with \(active.caregiverName). Cancel or complete it before creating a new booking.")
                            .font(CLTheme.captionFont)
                            .foregroundStyle(CLTheme.textSecondary)
                    }
                }

                connectionHelperRow
            } else {
                Text("Switch to a patient account to book caregivers.")
                    .font(CLTheme.captionFont)
                    .foregroundStyle(CLTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, CLTheme.spacingLG)
        .padding(.top, CLTheme.spacingMD)
        .padding(.bottom, CLTheme.spacingSM)
    }

    @ViewBuilder
    private var connectionHelperRow: some View {
        if existingConnection == nil {
            Button {
                requestConnection()
            } label: {
                HStack(spacing: 6) {
                    if isRequestingConnection {
                        ProgressView()
                    } else {
                        Image(systemName: "person.badge.plus")
                        Text("Request connection for ongoing care")
                            .font(CLTheme.calloutFont)
                    }
                }
                .foregroundStyle(CLTheme.accentBlue)
                .frame(maxWidth: .infinity)
            }
            .disabled(isRequestingConnection)
        } else if existingConnection?.status == .pending {
            HStack {
                Image(systemName: "clock.fill")
                Text("Connection request pending approval")
                    .font(CLTheme.calloutFont)
            }
            .foregroundStyle(CLTheme.warningOrange)
            .frame(maxWidth: .infinity)
        } else if existingConnection?.status == .approved {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(CLTheme.successGreen)
                Text("Connected for ongoing care")
                    .font(CLTheme.captionFont)
                    .foregroundStyle(CLTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Actions

    private func requestConnection() {
        isRequestingConnection = true
        Task {
            let userId = appState.authService.currentUser?.uid ?? ""
            let userName = appState.authService.userProfile?.fullName ?? "User"
            let connection = Connection(
                id: UUID().uuidString,
                userId: userId,
                userName: userName,
                caregiverId: caregiver.id,
                caregiverName: caregiver.name,
                caregiverSpecialty: caregiver.specialty,
                status: .pending,
                createdAt: Date()
            )
            do {
                try await appState.firestoreService.createConnection(connection)
                try? await appState.firestoreService.createNotification(
                    CLNotification(
                        id: UUID().uuidString,
                        userId: caregiver.id,
                        senderUserId: userId,
                        title: "New connection request",
                        message: "\(userName) requested an ongoing care connection.",
                        type: .connectionRequest,
                        isRead: false,
                        createdAt: Date()
                    )
                )
                existingConnection = connection
            } catch {
                print("Connection request failed: \(error)")
            }
            isRequestingConnection = false
        }
    }

    private func openChat() {
        Task {
            let userId = appState.authService.currentUser?.uid ?? ""
            let userName = appState.authService.userProfile?.fullName ?? "User"
            let conversation = try? await appState.chatService.getOrCreateConversation(
                userId: userId,
                userName: userName,
                caregiverId: caregiver.id,
                caregiverName: caregiver.name,
                caregiverSpecialty: caregiver.specialty
            )
            chatConversation = conversation
            showChat = true
        }
    }

    private func skillIcon(for skill: String) -> String {
        switch skill.lowercased() {
        case let s where s.contains("wound"): return "bandage.fill"
        case let s where s.contains("med"): return "pills.fill"
        case let s where s.contains("diet") || s.contains("nutrition") || s.contains("meal"): return "fork.knife"
        case let s where s.contains("vital") || s.contains("monitor"): return "heart.text.clipboard.fill"
        case let s where s.contains("rehab") || s.contains("mobility"): return "figure.walk"
        case let s where s.contains("pain"): return "cross.case.fill"
        case let s where s.contains("exercise"): return "dumbbell.fill"
        case let s where s.contains("first aid"): return "cross.fill"
        case let s where s.contains("education"): return "book.fill"
        case let s where s.contains("companion"): return "person.2.fill"
        case let s where s.contains("housekeep"): return "house.fill"
        default: return "checkmark.circle.fill"
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (positions, CGSize(width: maxWidth, height: y + rowHeight))
    }
}
