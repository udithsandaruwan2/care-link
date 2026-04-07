import SwiftUI

struct CaregiverCardView: View {
    let caregiver: Caregiver

    var body: some View {
        CLCard {
            HStack(spacing: CLTheme.spacingMD) {
                CaregiverAvatar(
                    size: 65,
                    imageURL: caregiver.imageURL,
                    showVerified: caregiver.isVerified
                )

                VStack(alignment: .leading, spacing: CLTheme.spacingXS) {
                    HStack {
                        Text(caregiver.name)
                            .font(CLTheme.headlineFont)
                            .foregroundStyle(CLTheme.textPrimary)
                            .lineLimit(1)

                        Spacer()

                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(CLTheme.starYellow)
                            Text(String(format: "%.1f", caregiver.rating))
                                .font(CLTheme.calloutFont)
                                .foregroundStyle(CLTheme.tealAccent)
                        }
                    }

                    Text("$\(String(format: "%.2f", caregiver.hourlyRate))/hr")
                        .font(CLTheme.calloutFont)
                        .foregroundStyle(CLTheme.accentBlue)

                    Text(caregiver.bio)
                        .font(CLTheme.captionFont)
                        .foregroundStyle(CLTheme.textSecondary)
                        .lineLimit(2)
                }
            }
        }
    }
}

#Preview {
    CaregiverCardView(caregiver: Caregiver(
        id: "preview", userId: "u1", name: "Sarah Jenkins", specialty: "Registered Nurse",
        title: "RN", hourlyRate: 35, rating: 4.9, reviewCount: 124, experienceYears: 8,
        distance: 0.8, bio: "Experienced nurse.", skills: [], certifications: [],
        availability: [], imageURL: "", latitude: 0, longitude: 0, isVerified: true,
        category: .elderly, phoneNumber: "", email: ""
    ))
    .padding()
}
