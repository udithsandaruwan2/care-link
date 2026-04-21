import SwiftUI
import FirebaseAuth

/// Unified patient surface for active requests, upcoming visits, and history.
struct MyCareHubView: View {
    @Environment(AppState.self) private var appState
    @State private var bookings: [Booking] = []
    @State private var isLoading = true
    @State private var loadError: String?

    private var awaitingCaregiver: [Booking] {
        bookings.filter { $0.status == .awaitingCaregiver || $0.status == .pending }
    }

    private var activeVisits: [Booking] {
        bookings.filter { $0.status == .confirmed || $0.status == .inProgress }
    }

    private var history: [Booking] {
        bookings.filter { $0.status == .completed || $0.status == .cancelled }
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, CLTheme.spacingXL)
            } else {
                hubContent
            }
        }
        .background(CLTheme.backgroundPrimary)
        .navigationTitle("My care hub")
        .navigationBarTitleDisplayMode(.inline)
        .task { await reload(showBlockingSpinner: true) }
        .refreshable { await reload(showBlockingSpinner: false) }
    }

    private var hubContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CLTheme.spacingLG) {
                if let loadError {
                    Text(loadError)
                        .font(CLTheme.captionFont)
                        .foregroundStyle(CLTheme.errorRed)
                        .padding(.horizontal, CLTheme.spacingMD)
                }

                if !awaitingCaregiver.isEmpty {
                    sectionHeader("Waiting on caregiver", subtitle: "Discovery is limited until this is resolved.")
                    ForEach(awaitingCaregiver) { booking in
                        hubCard(booking, emphasize: true)
                    }
                }

                if !activeVisits.isEmpty {
                    sectionHeader("Scheduled & in progress", subtitle: nil)
                    ForEach(activeVisits) { booking in
                        hubCard(booking, emphasize: booking.status.blocksNewBookingRequest)
                    }
                }

                sectionHeader("History", subtitle: nil)
                if history.isEmpty {
                    Text("Completed and cancelled visits appear here.")
                        .font(CLTheme.bodyFont)
                        .foregroundStyle(CLTheme.textTertiary)
                        .padding(.horizontal, CLTheme.spacingMD)
                } else {
                    ForEach(history) { booking in
                        hubCard(booking, emphasize: false)
                    }
                }
            }
            .padding(.vertical, CLTheme.spacingMD)
            .padding(.bottom, 100)
        }
    }

    private func sectionHeader(_ title: String, subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(CLTheme.title2Font)
                .foregroundStyle(CLTheme.textPrimary)
            if let subtitle {
                Text(subtitle)
                    .font(CLTheme.captionFont)
                    .foregroundStyle(CLTheme.textSecondary)
            }
        }
        .padding(.horizontal, CLTheme.spacingMD)
    }

    private func hubCard(_ booking: Booking, emphasize: Bool) -> some View {
        let patientUid = appState.authService.currentUser?.uid ?? ""
        return CLCard {
            VStack(alignment: .leading, spacing: CLTheme.spacingMD) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
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

                Label(
                    "\(booking.date.formatted(date: .abbreviated, time: .omitted)) · \(booking.startTime.formatted(date: .omitted, time: .shortened))",
                    systemImage: "calendar"
                )
                .font(CLTheme.captionFont)
                .foregroundStyle(CLTheme.textSecondary)

                Text("$\(String(format: "%.2f", booking.totalCost))")
                    .font(CLTheme.headlineFont)
                    .foregroundStyle(CLTheme.accentBlue)

                if emphasize {
                    Text("You have an open care pipeline with this caregiver. Finish or cancel before booking someone else.")
                        .font(CLTheme.captionFont)
                        .foregroundStyle(CLTheme.textTertiary)
                }

                if BookingStateMachine.patientMayRequestCancel(status: booking.status) {
                    Button {
                        Task {
                            do {
                                let updated = try await appState.firestoreService.applyBookingTransition(
                                    bookingId: booking.id,
                                    to: .cancelled,
                                    actor: .patient,
                                    callerUid: patientUid
                                )
                                if let index = bookings.firstIndex(where: { $0.id == booking.id }) {
                                    bookings[index] = updated
                                }
                            } catch {
                                loadError = error.localizedDescription
                            }
                        }
                    } label: {
                        Text("Cancel request")
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
        .padding(.horizontal, CLTheme.spacingMD)
    }

    private func reload(showBlockingSpinner: Bool) async {
        if showBlockingSpinner { isLoading = true }
        let userId = appState.authService.currentUser?.uid ?? ""
        defer {
            if showBlockingSpinner { isLoading = false }
        }
        do {
            bookings = try await appState.firestoreService.fetchBookings(for: userId)
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        MyCareHubView()
            .environment(AppState())
    }
}
