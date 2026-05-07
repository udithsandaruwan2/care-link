import SwiftUI

struct PatientProfileView: View {
    @Environment(AppState.self) private var appState
    let patient: CLUser?
    let booking: Booking?

    private var displayName: String {
        if let fullName = patient?.fullName, !fullName.isEmpty { return fullName }
        if let patientName = booking?.patientName, !patientName.isEmpty { return patientName }
        return "Patient"
    }

    private var displayPhone: String {
        let phone = patient?.phoneNumber ?? ""
        return phone.isEmpty ? "No phone on file" : phone
    }

    private var displayEmail: String {
        let email = patient?.email ?? ""
        return email.isEmpty ? "No email on file" : email
    }

    private var displayAddress: String {
        let address = patient?.address ?? ""
        return address.isEmpty ? "No address on file" : address
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CLTheme.spacingLG) {
                headerCard
                contactCard
                if let booking {
                    sessionCard(booking)
                }
            }
            .padding(CLTheme.spacingMD)
            .padding(.bottom, 100)
        }
        .background(CLTheme.backgroundPrimary)
        .navigationTitle("Patient Profile")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerCard: some View {
        CLCard {
            HStack(spacing: CLTheme.spacingMD) {
                Circle()
                    .fill(CLTheme.primaryNavy.opacity(0.12))
                    .frame(width: 64, height: 64)
                    .overlay {
                        Text(String(displayName.prefix(2)).uppercased())
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(CLTheme.primaryNavy)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(displayName)
                        .font(CLTheme.title2Font)
                        .foregroundStyle(CLTheme.textPrimary)
                    Text(patient?.role == .caregiver ? "Caregiver" : "Patient")
                        .font(CLTheme.captionFont)
                        .foregroundStyle(CLTheme.textSecondary)
                }
                Spacer()
            }
        }
    }

    private var contactCard: some View {
        CLCard {
            VStack(alignment: .leading, spacing: CLTheme.spacingSM) {
                Text("Contact")
                    .font(CLTheme.headlineFont)
                    .foregroundStyle(CLTheme.textPrimary)
                infoRow(title: "Phone", value: displayPhone)
                infoRow(title: "Email", value: displayEmail)
                infoRow(title: "Address", value: displayAddress)
            }
        }
    }

    private func sessionCard(_ booking: Booking) -> some View {
        CLCard {
            VStack(alignment: .leading, spacing: CLTheme.spacingSM) {
                Text("Active Session")
                    .font(CLTheme.headlineFont)
                    .foregroundStyle(CLTheme.textPrimary)
                infoRow(title: "Status", value: booking.status.rawValue)
                infoRow(
                    title: "Schedule",
                    value: "\(booking.date.formatted(date: .abbreviated, time: .omitted)) · \(booking.startTime.formatted(date: .omitted, time: .shortened)) - \(booking.endTime.formatted(date: .omitted, time: .shortened))"
                )
                infoRow(title: "Location", value: booking.location.isEmpty ? booking.address : booking.location)
            }
        }
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(CLTheme.captionFont)
                .foregroundStyle(CLTheme.textTertiary)
                .frame(width: 74, alignment: .leading)
            Text(value)
                .font(CLTheme.calloutFont)
                .foregroundStyle(CLTheme.textPrimary)
            Spacer()
        }
    }
}

