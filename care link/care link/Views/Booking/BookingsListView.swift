import SwiftUI
import FirebaseAuth

struct BookingsListView: View {
    @Environment(AppState.self) private var appState
    @State private var bookings: [Booking] = []
    @State private var selectedFilter: Booking.BookingStatus? = nil
    @State private var isLoading = true

    var filteredBookings: [Booking] {
        guard let filter = selectedFilter else { return bookings }
        return bookings.filter { $0.status == filter }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("My Bookings")
                    .font(CLTheme.titleFont)
                    .foregroundStyle(CLTheme.textPrimary)
                Spacer()
            }
            .padding(.horizontal, CLTheme.spacingMD)
            .padding(.vertical, CLTheme.spacingSM)

            filterBar

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredBookings.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: CLTheme.spacingMD) {
                        ForEach(filteredBookings) { booking in
                            bookingCard(booking)
                        }
                    }
                    .padding(.horizontal, CLTheme.spacingMD)
                    .padding(.bottom, 100)
                }
            }
        }
        .background(CLTheme.backgroundPrimary)
        .task {
            let userId = appState.authService.currentUser?.uid ?? ""
            do {
                bookings = try await appState.firestoreService.fetchBookings(for: userId)
            } catch {}
            isLoading = false
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: CLTheme.spacingSM) {
                CLChip(title: "All", isSelected: selectedFilter == nil) {
                    selectedFilter = nil
                }
                ForEach(Booking.BookingStatus.allCases, id: \.self) { status in
                    CLChip(title: status.rawValue, isSelected: selectedFilter == status) {
                        selectedFilter = status
                    }
                }
            }
            .padding(.horizontal, CLTheme.spacingMD)
            .padding(.vertical, CLTheme.spacingSM)
        }
    }

    private func bookingCard(_ booking: Booking) -> some View {
        CLCard {
            VStack(spacing: CLTheme.spacingMD) {
                HStack(spacing: CLTheme.spacingMD) {
                    CaregiverAvatar(size: 50)

                    VStack(alignment: .leading, spacing: CLTheme.spacingXS) {
                        Text(booking.caregiverName)
                            .font(CLTheme.headlineFont)
                            .foregroundStyle(CLTheme.textPrimary)
                        Text(booking.caregiverSpecialty)
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

                Divider()

                HStack {
                    Label(
                        booking.date.formatted(date: .abbreviated, time: .omitted),
                        systemImage: "calendar"
                    )
                    .font(CLTheme.captionFont)
                    .foregroundStyle(CLTheme.textSecondary)

                    Spacer()

                    Label(
                        booking.startTime.formatted(date: .omitted, time: .shortened),
                        systemImage: "clock"
                    )
                    .font(CLTheme.captionFont)
                    .foregroundStyle(CLTheme.textSecondary)

                    Spacer()

                    Text("$\(String(format: "%.2f", booking.totalCost))")
                        .font(CLTheme.headlineFont)
                        .foregroundStyle(CLTheme.accentBlue)
                }

                if booking.status == .pending {
                    Button {
                        Task {
                            try? await appState.firestoreService.updateBookingStatus(
                                bookingId: booking.id,
                                status: .cancelled
                            )
                            if let index = bookings.firstIndex(where: { $0.id == booking.id }) {
                                bookings[index].status = .cancelled
                            }
                        }
                    } label: {
                        Text("Cancel Booking")
                            .font(CLTheme.calloutFont)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .foregroundStyle(CLTheme.errorRed)
                            .background(CLTheme.errorRed.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: CLTheme.cornerRadiusSM))
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: CLTheme.spacingMD) {
            Spacer()
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(CLTheme.textTertiary)
            Text("No bookings found")
                .font(CLTheme.headlineFont)
                .foregroundStyle(CLTheme.textSecondary)
            Text("Your booking history will appear here once you book a caregiver.")
                .font(CLTheme.bodyFont)
                .foregroundStyle(CLTheme.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, CLTheme.spacingXL)
            Spacer()
        }
    }
}

#Preview {
    BookingsListView()
        .environment(AppState())
}
