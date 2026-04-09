import SwiftUI
import FirebaseAuth

struct CaregiverProfileEditView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = CaregiverPortalViewModel()

    @State private var name = ""
    @State private var specialty = ""
    @State private var bio = ""
    @State private var hourlyRate = ""
    @State private var skills = ""
    @State private var certifications = ""
    @State private var isSaving = false
    @State private var showSaved = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: CLTheme.spacingLG) {
                    VStack(spacing: CLTheme.spacingMD) {
                        CaregiverAvatar(size: 90, showVerified: true)

                        Button("Change Photo") {}
                            .font(CLTheme.calloutFont.weight(.medium))
                            .foregroundStyle(CLTheme.accentBlue)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(CLTheme.lightBlue.opacity(0.5))
                            .clipShape(Capsule())
                            .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity)

                    formSection("Personal Information") {
                        formField("Full Name", text: $name, icon: "person")
                        formField("Specialty", text: $specialty, icon: "stethoscope")
                        formField("Hourly Rate ($)", text: $hourlyRate, icon: "dollarsign.circle", keyboard: .decimalPad)
                    }

                    formSection("About Me") {
                        VStack(alignment: .leading, spacing: CLTheme.spacingXS) {
                            Text("BIO")
                                .font(CLTheme.smallFont)
                                .foregroundStyle(CLTheme.textTertiary)
                                .tracking(1)
                            TextEditor(text: $bio)
                                .font(CLTheme.bodyFont)
                                .frame(minHeight: 120)
                                .padding(CLTheme.spacingSM)
                                .background(CLTheme.backgroundSecondary)
                                .clipShape(CLTheme.continuousRect(cornerRadius: CLTheme.cornerRadiusMD))
                        }
                    }

                    formSection("Skills & Certifications") {
                        formField("Skills (comma separated)", text: $skills, icon: "checkmark.seal")
                        formField("Certifications (comma separated)", text: $certifications, icon: "rosette")
                    }

                    CLButton(title: showSaved ? "Saved!" : "Save Changes", icon: showSaved ? "checkmark" : "arrow.up.circle", isLoading: isSaving) {
                        saveProfile()
                    }
                    .padding(.horizontal, CLTheme.spacingMD)
                    .padding(.bottom, CLTheme.spacingXL)
                }
            }
            .background(CLTheme.backgroundPrimary)
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(CLTheme.textSecondary)
                }
            }
        }
    }

    private func formSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: CLTheme.spacingMD) {
            Text(title)
                .font(CLTheme.title2Font)
                .foregroundStyle(CLTheme.textPrimary)
                .padding(.horizontal, CLTheme.spacingMD)

            VStack(spacing: CLTheme.spacingMD) {
                content()
            }
            .padding(CLTheme.spacingMD)
            .background(CLTheme.cardBackground)
            .clipShape(CLTheme.continuousRect(cornerRadius: CLTheme.cornerRadiusLG))
            .shadow(color: CLTheme.shadowLight, radius: 6, y: 2)
            .padding(.horizontal, CLTheme.spacingMD)
        }
    }

    private func formField(_ placeholder: String, text: Binding<String>, icon: String, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: CLTheme.spacingXS) {
            Text(placeholder.uppercased())
                .font(CLTheme.smallFont)
                .foregroundStyle(CLTheme.textTertiary)
                .tracking(1)
            CLTextField(placeholder: placeholder, text: text, icon: icon, keyboardType: keyboard)
        }
    }

    private func saveProfile() {
        isSaving = true
        Task {
            let uid = appState.authService.currentUser?.uid ?? UUID().uuidString
            let existing = viewModel.caregiverProfile
            let caregiver = Caregiver(
                id: existing?.id ?? uid,
                userId: uid,
                name: name,
                specialty: specialty,
                title: existing?.title ?? "RN",
                hourlyRate: Double(hourlyRate) ?? 0,
                rating: existing?.rating ?? 0,
                reviewCount: existing?.reviewCount ?? 0,
                experienceYears: existing?.experienceYears ?? 0,
                distance: existing?.distance ?? 0,
                bio: bio,
                skills: skills.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) },
                certifications: certifications.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) },
                availability: existing?.availability ?? [],
                imageURL: existing?.imageURL ?? "",
                latitude: existing?.latitude ?? 0,
                longitude: existing?.longitude ?? 0,
                isVerified: existing?.isVerified ?? false,
                category: existing?.category ?? .all,
                phoneNumber: existing?.phoneNumber ?? "",
                email: appState.authService.userProfile?.email ?? ""
            )
            await viewModel.updateProfile(caregiver: caregiver, firestoreService: appState.firestoreService)
            isSaving = false
            showSaved = true
            try? await Task.sleep(for: .seconds(2))
            showSaved = false
        }
    }
}

#Preview {
    CaregiverProfileEditView()
        .environment(AppState())
}
