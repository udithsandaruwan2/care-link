import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CLTheme.spacingLG) {
                section(
                    title: "Data We Collect",
                    body: "CareLink stores profile details, bookings, conversations, and medical records needed to provide care coordination."
                )
                section(
                    title: "How We Use Data",
                    body: "Your data is used to match patients with caregivers, support communication, and maintain care history and medical notes."
                )
                section(
                    title: "Who Can Access Data",
                    body: "Only authenticated participants (patient and assigned caregiver) can access booking and medical record information related to their care."
                )
                section(
                    title: "Retention and Control",
                    body: "You can request account deletion from Settings. This removes your profile and associated app data per system policy."
                )
                section(
                    title: "Support Contact",
                    body: "For privacy requests, contact support@carelink.app."
                )
            }
            .padding(CLTheme.spacingMD)
            .padding(.bottom, 40)
        }
        .background(CLTheme.backgroundPrimary)
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section(title: String, body: String) -> some View {
        CLCard {
            VStack(alignment: .leading, spacing: CLTheme.spacingSM) {
                Text(title)
                    .font(CLTheme.title2Font)
                    .foregroundStyle(CLTheme.textPrimary)
                Text(body)
                    .font(CLTheme.bodyFont)
                    .foregroundStyle(CLTheme.textSecondary)
            }
        }
    }
}

