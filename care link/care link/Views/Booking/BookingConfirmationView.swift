import SwiftUI

struct BookingConfirmationView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let booking: Booking
    let caregiver: Caregiver
    @State private var addedToCalendar = false
    @State private var animate = false
    @State private var showBookingSummary = false

    var body: some View {
        ScrollView {
            VStack(spacing: CLTheme.spacingLG) {
                Spacer(minLength: CLTheme.spacingXL)

                VStack(spacing: CLTheme.spacingMD) {
                    ZStack {
                        Circle()
                            .fill(CLTheme.successGreen.opacity(0.15))
                            .frame(width: 90, height: 90)
                            .scaleEffect(animate ? 1.0 : 0.5)

                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(CLTheme.successGreen)
                            .scaleEffect(animate ? 1.0 : 0.3)
                    }

                    Text("Booking request sent")
                        .font(CLTheme.titleFont)
                        .foregroundStyle(CLTheme.primaryNavy)

                    Text("Your caregiver will review your request shortly.")
                        .font(CLTheme.bodyFont)
                        .foregroundStyle(CLTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, CLTheme.spacingLG)

                CLCard {
                    VStack(spacing: CLTheme.spacingSM) {
                        Text("ASSIGNED CAREGIVER")
                            .font(CLTheme.smallFont)
                            .foregroundStyle(CLTheme.textTertiary)
                            .tracking(1)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: CLTheme.spacingMD) {
                            CaregiverAvatar(size: 50, showVerified: caregiver.isVerified)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(caregiver.name), \(caregiver.title)")
                                    .font(CLTheme.headlineFont)
                                    .foregroundStyle(CLTheme.textPrimary)
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(CLTheme.starYellow)
                                    Text("\(String(format: "%.1f", caregiver.rating)) (\(caregiver.reviewCount) reviews)")
                                        .font(CLTheme.captionFont)
                                        .foregroundStyle(CLTheme.textSecondary)
                                }
                            }
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, CLTheme.spacingMD)

                HStack(spacing: CLTheme.spacingMD) {
                    CLInfoCard(
                        icon: "calendar",
                        label: "Date",
                        value: booking.date.formatted(date: .abbreviated, time: .omitted)
                    )
                    CLInfoCard(
                        icon: "clock",
                        label: "Time",
                        value: "\(booking.startTime.formatted(date: .omitted, time: .shortened)) - \(booking.endTime.formatted(date: .omitted, time: .shortened))"
                    )
                }
                .padding(.horizontal, CLTheme.spacingMD)

                CLCard {
                    HStack(spacing: CLTheme.spacingMD) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: booking.paymentMethod.colorHex).opacity(0.15))
                                .frame(width: 44, height: 44)
                            Image(systemName: booking.paymentMethod.iconName)
                                .font(.system(size: 20))
                                .foregroundStyle(Color(hex: booking.paymentMethod.colorHex))
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("PAYMENT METHOD")
                                .font(CLTheme.smallFont)
                                .foregroundStyle(CLTheme.textTertiary)
                                .tracking(1)
                            Text(booking.paymentMethod.displayName)
                                .font(CLTheme.headlineFont)
                                .foregroundStyle(CLTheme.textPrimary)
                        }

                        Spacer()

                        Text("$\(String(format: "%.2f", booking.totalCost))")
                            .font(CLTheme.titleFont)
                            .foregroundStyle(CLTheme.textPrimary)
                    }
                }
                .padding(.horizontal, CLTheme.spacingMD)

                CLCard {
                    HStack {
                        VStack(alignment: .leading, spacing: CLTheme.spacingSM) {
                            HStack(spacing: 4) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(CLTheme.accentBlue)
                                Text("LOCATION")
                                    .font(CLTheme.smallFont)
                                    .foregroundStyle(CLTheme.textTertiary)
                                    .tracking(1)
                            }
                            Text(booking.location)
                                .font(CLTheme.headlineFont)
                                .foregroundStyle(CLTheme.textPrimary)
                            Text(booking.address)
                                .font(CLTheme.captionFont)
                                .foregroundStyle(CLTheme.textSecondary)
                        }
                        Spacer()
                        RoundedRectangle(cornerRadius: CLTheme.cornerRadiusSM)
                            .fill(CLTheme.backgroundSecondary)
                            .frame(width: 56, height: 56)
                            .overlay {
                                Image(systemName: "map.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(CLTheme.textTertiary)
                            }
                    }
                }
                .padding(.horizontal, CLTheme.spacingMD)

                VStack(spacing: CLTheme.spacingMD) {
                    CLButton(title: "Add to Calendar", icon: "calendar.badge.plus", style: addedToCalendar ? .secondary : .primary) {
                        Task {
                            addedToCalendar = await appState.eventKitService.addBookingToCalendar(booking: booking)
                        }
                    }

                    CLButton(title: "View Booking Details", style: .primary) {
                        showBookingSummary = true
                    }

                    CLButton(title: "Back to Home", style: .secondary) {
                        navigateToHome()
                    }
                }
                .padding(.horizontal, CLTheme.spacingLG)

                Text("You can modify or cancel this request up to 24 hours before the scheduled start time without any fees.")
                    .font(CLTheme.captionFont)
                    .foregroundStyle(CLTheme.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, CLTheme.spacingXL)
                    .padding(.bottom, CLTheme.spacingXL)
            }
        }
        .background(CLTheme.backgroundPrimary)
        .navigationBarBackButtonHidden()
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                animate = true
            }
        }
        .sheet(isPresented: $showBookingSummary) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: CLTheme.spacingMD) {
                        bookingSummaryRows
                    }
                    .padding()
                }
                .background(CLTheme.backgroundPrimary)
                .navigationTitle("Booking")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { showBookingSummary = false }
                    }
                }
            }
        }
    }

    private var bookingSummaryRows: some View {
        VStack(alignment: .leading, spacing: CLTheme.spacingLG) {
            LabeledContent("Status", value: booking.status.rawValue)
            LabeledContent(
                "Care Recipient",
                value: booking.careRecipientRelation == nil
                    ? booking.patientName
                    : "\(booking.patientName) (\(booking.careRecipientRelation ?? ""))"
            )
            LabeledContent("Caregiver", value: "\(caregiver.name) · \(caregiver.specialty)")
            LabeledContent("When", value: "\(booking.date.formatted(date: .abbreviated, time: .omitted)), \(booking.startTime.formatted(date: .omitted, time: .shortened)) – \(booking.endTime.formatted(date: .omitted, time: .shortened))")
            LabeledContent("Duration", value: String(format: "%.1f hours", booking.duration))
            LabeledContent("Total", value: String(format: "$%.2f", booking.totalCost))
            LabeledContent("Payment", value: booking.paymentMethod.displayName)
            LabeledContent("Location", value: "\(booking.location) — \(booking.address)")
        }
        .font(CLTheme.bodyFont)
    }

    private func navigateToHome() {
        appState.navigationResetToken = UUID()
    }
}

#Preview {
    BookingConfirmationView(
        booking: Booking(
            id: "bk_preview", userId: "u1", patientName: "You", caregiverId: "cg1", caregiverName: "Sarah Jenkins",
            caregiverSpecialty: "RN", caregiverImageURL: "", caregiverRating: 4.9,
            date: Date(), startTime: Date(), endTime: Date().addingTimeInterval(3600 * 2),
            duration: 2, totalCost: 70, status: .pending, location: "Home", address: "123 St",
            paymentMethod: .card, createdAt: Date()
        ),
        caregiver: Caregiver(
            id: "cg1", userId: "u2", name: "Sarah Jenkins", specialty: "RN",
            title: "RN", hourlyRate: 35, rating: 4.9, reviewCount: 10, experienceYears: 8,
            distance: 1, bio: "", skills: [], certifications: [], availability: [],
            imageURL: "", latitude: 0, longitude: 0, isVerified: true, category: .elderly,
            phoneNumber: "", email: ""
        )
    )
    .environment(AppState())
}
