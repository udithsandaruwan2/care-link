import SwiftUI
import FirebaseAuth

struct BookingDetailsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let caregiver: Caregiver
    @State private var viewModel = BookingViewModel()
    @State private var showConfirmation = false
    @State private var bookingHistory: [Booking] = []
    @State private var familyMembers: [FamilyMember] = []
    @State private var selectedRecipientId = "self"
    @State private var showInternetAlert = false

    private var hasBlockingBooking: Bool {
        bookingHistory.contains(where: { $0.status.blocksNewBookingRequest })
    }

    private let popularDurations = ["Morning (4h)", "Afternoon (3h)", "Full Day (8h)"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CLTheme.spacingLG) {
                caregiverCard
                dateSection
                timeSection
                careRecipientSection
                durationInfo
                popularDurationsSection
                paymentMethodSection
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
                HStack(spacing: CLTheme.spacingSM) {
                    Image(systemName: "cross.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(CLTheme.primaryNavy)
                    Text("CareLink")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(CLTheme.primaryNavy)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 16))
                    .foregroundStyle(CLTheme.textPrimary)
            }
        }
        .navigationDestination(isPresented: $showConfirmation) {
            if let booking = viewModel.confirmedBooking {
                BookingConfirmationView(booking: booking, caregiver: caregiver)
                    .environment(appState)
            }
        }
        .task {
            await loadRiskContext()
        }
        .onChange(of: viewModel.selectedDate) { _, _ in recomputeRisk() }
        .onChange(of: viewModel.startTime) { _, _ in recomputeRisk() }
        .onChange(of: viewModel.endTime) { _, _ in recomputeRisk() }
        .onChange(of: viewModel.selectedPaymentMethod) { _, _ in recomputeRisk() }
        .alert("Booking", isPresented: $viewModel.showError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert("Internet Required", isPresented: $showInternetAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please turn on internet to continue this action.")
        }
    }

    private var caregiverCard: some View {
        VStack(alignment: .leading, spacing: CLTheme.spacingMD) {
            Text("Booking Details")
                .font(CLTheme.titleFont)
                .foregroundStyle(CLTheme.textPrimary)
                .padding(.horizontal, CLTheme.spacingMD)

            CLCard {
                HStack(spacing: CLTheme.spacingMD) {
                    CaregiverAvatar(size: 55, imageURL: caregiver.imageURL, showVerified: caregiver.isVerified)

                    VStack(alignment: .leading, spacing: CLTheme.spacingXS) {
                        Text(caregiver.name)
                            .font(CLTheme.headlineFont)
                            .foregroundStyle(CLTheme.textPrimary)
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(CLTheme.tealAccent)
                            Text(caregiver.specialty)
                                .font(CLTheme.captionFont)
                                .foregroundStyle(CLTheme.textSecondary)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing) {
                        Text("$\(String(format: "%.0f", caregiver.hourlyRate))")
                            .font(CLTheme.titleFont)
                            .foregroundStyle(CLTheme.textPrimary)
                        Text("/hr")
                            .font(CLTheme.captionFont)
                            .foregroundStyle(CLTheme.textTertiary)
                    }
                }
            }
            .padding(.horizontal, CLTheme.spacingMD)
        }
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: CLTheme.spacingMD) {
            Text("Select Date")
                .font(CLTheme.title2Font)
                .foregroundStyle(CLTheme.textPrimary)
                .padding(.horizontal, CLTheme.spacingMD)

            DatePicker(
                "Select Date",
                selection: $viewModel.selectedDate,
                in: Date()...,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .tint(CLTheme.primaryNavy)
            .padding(.horizontal, CLTheme.spacingMD)
        }
    }

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: CLTheme.spacingMD) {
            Text("Select Time")
                .font(CLTheme.title2Font)
                .foregroundStyle(CLTheme.textPrimary)
                .padding(.horizontal, CLTheme.spacingMD)

            HStack(spacing: CLTheme.spacingMD) {
                VStack(alignment: .leading, spacing: CLTheme.spacingXS) {
                    Text("START TIME")
                        .font(CLTheme.smallFont)
                        .foregroundStyle(CLTheme.textTertiary)
                        .tracking(1)
                    DatePicker("", selection: $viewModel.startTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .tint(CLTheme.primaryNavy)
                        .padding(.horizontal, CLTheme.spacingMD)
                        .padding(.vertical, CLTheme.spacingSM)
                        .background(CLTheme.backgroundSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: CLTheme.cornerRadiusMD))
                }

                VStack(alignment: .leading, spacing: CLTheme.spacingXS) {
                    Text("END TIME")
                        .font(CLTheme.smallFont)
                        .foregroundStyle(CLTheme.textTertiary)
                        .tracking(1)
                    DatePicker("", selection: $viewModel.endTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .tint(CLTheme.primaryNavy)
                        .padding(.horizontal, CLTheme.spacingMD)
                        .padding(.vertical, CLTheme.spacingSM)
                        .background(CLTheme.backgroundSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: CLTheme.cornerRadiusMD))
                }
            }
            .padding(.horizontal, CLTheme.spacingMD)
        }
    }

    private var durationInfo: some View {
        VStack(alignment: .leading, spacing: CLTheme.spacingSM) {
            HStack(spacing: CLTheme.spacingSM) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(CLTheme.accentBlue)
                Text("Total duration: \(String(format: "%.1f", viewModel.duration)) hours")
                    .font(CLTheme.calloutFont)
                    .foregroundStyle(CLTheme.accentBlue)
            }
            if selectedRecipientId != "self", let relation = selectedFamilyMember?.relation {
                Text("Care recipient: \(selectedRecipientName) (\(relation))")
                    .font(CLTheme.captionFont)
                    .foregroundStyle(CLTheme.textSecondary)
            } else {
                Text("Care recipient: \(selectedRecipientName)")
                    .font(CLTheme.captionFont)
                    .foregroundStyle(CLTheme.textSecondary)
            }
            if let risk = viewModel.riskAssessment {
                HStack(spacing: 8) {
                    Image(systemName: risk.level == .high ? "exclamationmark.triangle.fill" : "shield.lefthalf.filled")
                        .foregroundStyle(riskColor(risk.level))
                    Text("\(risk.shortText) for this slot")
                        .font(CLTheme.captionFont)
                        .foregroundStyle(riskColor(risk.level))
                    Spacer(minLength: 0)
                    Text(risk.source == "coreml" ? "Core ML" : "Fallback")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(CLTheme.textTertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CLTheme.spacingMD)
        .background(CLTheme.lightBlue)
        .clipShape(RoundedRectangle(cornerRadius: CLTheme.cornerRadiusMD))
        .padding(.horizontal, CLTheme.spacingMD)
    }

    private var careRecipientSection: some View {
        VStack(alignment: .leading, spacing: CLTheme.spacingMD) {
            Text("Who needs care?")
                .font(CLTheme.title2Font)
                .foregroundStyle(CLTheme.textPrimary)
                .padding(.horizontal, CLTheme.spacingMD)

            VStack(spacing: CLTheme.spacingSM) {
                recipientRow(
                    id: "self",
                    title: appState.authService.userProfile?.fullName ?? "Me",
                    subtitle: "Account holder (default)"
                )
                ForEach(familyMembers) { member in
                    recipientRow(
                        id: member.id,
                        title: member.fullName,
                        subtitle: member.relation
                    )
                }
            }
            .padding(.horizontal, CLTheme.spacingMD)
        }
    }

    private func recipientRow(id: String, title: String, subtitle: String) -> some View {
        let isSelected = selectedRecipientId == id
        return Button {
            selectedRecipientId = id
            recomputeRisk()
        } label: {
            HStack(spacing: CLTheme.spacingMD) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? CLTheme.accentBlue : CLTheme.textTertiary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(CLTheme.bodyFont)
                        .foregroundStyle(CLTheme.textPrimary)
                    Text(subtitle)
                        .font(CLTheme.captionFont)
                        .foregroundStyle(CLTheme.textSecondary)
                }
                Spacer()
            }
            .padding(CLTheme.spacingMD)
            .background(CLTheme.cardBackground)
            .clipShape(CLTheme.continuousRect(cornerRadius: CLTheme.cornerRadiusMD))
        }
        .buttonStyle(.plain)
    }

    private var popularDurationsSection: some View {
        VStack(alignment: .leading, spacing: CLTheme.spacingSM) {
            Text("POPULAR DURATIONS")
                .font(CLTheme.smallFont)
                .foregroundStyle(CLTheme.textTertiary)
                .tracking(1)
                .padding(.horizontal, CLTheme.spacingMD)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: CLTheme.spacingSM) {
                    ForEach(popularDurations, id: \.self) { duration in
                        CLChip(
                            title: duration,
                            isSelected: viewModel.selectedDuration == duration
                        ) {
                            viewModel.selectPopularDuration(duration)
                        }
                    }
                }
                .padding(.horizontal, CLTheme.spacingMD)
            }
        }
    }

    // MARK: - Payment Method

    private var paymentMethodSection: some View {
        VStack(alignment: .leading, spacing: CLTheme.spacingMD) {
            Text("Payment Method")
                .font(CLTheme.title2Font)
                .foregroundStyle(CLTheme.textPrimary)
                .padding(.horizontal, CLTheme.spacingMD)

            HStack(spacing: CLTheme.spacingMD) {
                ForEach(Booking.PaymentMethod.allCases, id: \.self) { method in
                    paymentMethodCard(method)
                }
            }
            .padding(.horizontal, CLTheme.spacingMD)
        }
    }

    private func paymentMethodCard(_ method: Booking.PaymentMethod) -> some View {
        let isSelected = viewModel.selectedPaymentMethod == method
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.selectedPaymentMethod = method
            }
        } label: {
            VStack(spacing: CLTheme.spacingSM) {
                ZStack {
                    Circle()
                        .fill(isSelected
                              ? Color(hex: method.colorHex).opacity(0.15)
                              : CLTheme.backgroundSecondary)
                        .frame(width: 52, height: 52)
                    Image(systemName: method.iconName)
                        .font(.system(size: 22))
                        .foregroundStyle(isSelected
                                         ? Color(hex: method.colorHex)
                                         : CLTheme.textTertiary)
                }

                Text(method.displayName)
                    .font(CLTheme.headlineFont)
                    .foregroundStyle(isSelected ? CLTheme.textPrimary : CLTheme.textSecondary)

                Text(method == .card ? "Pay with card" : "Pay in person")
                    .font(CLTheme.captionFont)
                    .foregroundStyle(CLTheme.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, CLTheme.spacingMD)
            .background(isSelected ? Color(hex: method.colorHex).opacity(0.06) : CLTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: CLTheme.cornerRadiusLG))
            .overlay {
                RoundedRectangle(cornerRadius: CLTheme.cornerRadiusLG)
                    .stroke(isSelected ? Color(hex: method.colorHex) : CLTheme.divider,
                            lineWidth: isSelected ? 2 : 1)
            }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: CLTheme.spacingMD) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Estimated Total")
                        .font(CLTheme.bodyFont)
                        .foregroundStyle(CLTheme.textSecondary)
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.selectedPaymentMethod.iconName)
                            .font(.system(size: 12))
                            .foregroundStyle(Color(hex: viewModel.selectedPaymentMethod.colorHex))
                        Text(viewModel.selectedPaymentMethod.displayName)
                            .font(CLTheme.captionFont)
                            .foregroundStyle(Color(hex: viewModel.selectedPaymentMethod.colorHex))
                    }
                }
                Spacer()
                Text("$\(String(format: "%.2f", viewModel.estimatedTotal(for: caregiver)))")
                    .font(CLTheme.titleFont)
                    .foregroundStyle(CLTheme.textPrimary)
            }

            CLButton(title: "Confirm Booking", icon: "arrow.right", isLoading: viewModel.isLoading) {
                Task {
                    guard appState.networkMonitor.isConnected else {
                        showInternetAlert = true
                        return
                    }
                    let userId = appState.authService.currentUser?.uid ?? ""
                    guard !userId.isEmpty else { return }
                    let patientName = selectedRecipientName
                    let patientAddress = appState.authService.userProfile?.address ?? ""
                    viewModel.updateRiskAssessment(
                        caregiver: caregiver,
                        userId: userId,
                        patientName: patientName,
                        patientAddress: patientAddress,
                        careRecipientId: selectedRecipientId == "self" ? nil : selectedRecipientId,
                        careRecipientRelation: selectedFamilyMember?.relation,
                        userHistory: bookingHistory,
                        riskService: appState.coreMLBookingRiskService
                    )
                    let success = await viewModel.confirmBooking(
                        caregiver: caregiver,
                        userId: userId,
                        patientName: patientName,
                        patientAddress: patientAddress,
                        careRecipientId: selectedRecipientId == "self" ? nil : selectedRecipientId,
                        careRecipientRelation: selectedFamilyMember?.relation,
                        firestoreService: appState.firestoreService,
                        chatService: appState.chatService
                    )
                    if success {
                        appState.notificationService.scheduleLocalNotification(
                            title: "Booking Request Sent",
                            body: "Your request to \(caregiver.name) has been submitted."
                        )
                        showConfirmation = true
                    }
                }
            }
            .disabled(hasBlockingBooking || viewModel.isLoading)

            if let existing = bookingHistory.first(where: { $0.status.blocksNewBookingRequest }) {
                Text("Active request with \(existing.caregiverName) (\(existing.status.rawValue)). Complete or cancel it before booking another caregiver.")
                    .font(CLTheme.captionFont)
                    .foregroundStyle(CLTheme.warningOrange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, CLTheme.spacingLG)
        .padding(.top, CLTheme.spacingMD)
        .padding(.bottom, CLTheme.spacingSM)
    }

    private func loadRiskContext() async {
        let userId = appState.authService.currentUser?.uid ?? ""
        guard !userId.isEmpty else { return }
        guard appState.networkMonitor.isConnected else { return }
        await viewModel.loadUserBookings(userId: userId, firestoreService: appState.firestoreService)
        bookingHistory = viewModel.userBookings
        familyMembers = (try? await appState.firestoreService.fetchFamilyMembers(for: userId)) ?? []
        recomputeRisk()
    }

    private func recomputeRisk() {
        let userId = appState.authService.currentUser?.uid ?? ""
        guard !userId.isEmpty else { return }
        viewModel.updateRiskAssessment(
            caregiver: caregiver,
            userId: userId,
            patientName: selectedRecipientName,
            patientAddress: appState.authService.userProfile?.address ?? "",
            careRecipientId: selectedRecipientId == "self" ? nil : selectedRecipientId,
            careRecipientRelation: selectedFamilyMember?.relation,
            userHistory: bookingHistory,
            riskService: appState.coreMLBookingRiskService
        )
    }

    private var selectedFamilyMember: FamilyMember? {
        familyMembers.first(where: { $0.id == selectedRecipientId })
    }

    private var selectedRecipientName: String {
        if selectedRecipientId == "self" {
            return appState.authService.userProfile?.fullName ?? "Patient"
        }
        return selectedFamilyMember?.fullName ?? (appState.authService.userProfile?.fullName ?? "Patient")
    }

    private func riskColor(_ level: BookingRiskAssessment.Level) -> Color {
        switch level {
        case .low: return CLTheme.successGreen
        case .medium: return CLTheme.warningOrange
        case .high: return CLTheme.errorRed
        }
    }
}

#Preview {
    NavigationStack {
        BookingDetailsView(caregiver: Caregiver(
            id: "preview", userId: "u1", name: "Sarah Jenkins", specialty: "Registered Nurse",
            title: "RN", hourlyRate: 35, rating: 4.9, reviewCount: 124, experienceYears: 8,
            distance: 0.8, bio: "Experienced nurse.", skills: ["Wound Care"], certifications: ["BLS"],
            availability: ["Morning"], imageURL: "", latitude: 6.9271, longitude: 79.8612,
            isVerified: true, category: .elderly, phoneNumber: "", email: ""
        ))
        .environment(AppState())
    }
}
