// File responsibility: Defines caregiver profile edit view logic for the care link app.

import SwiftUI
import FirebaseAuth

struct CaregiverProfileEditView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = CaregiverPortalViewModel()

    @State private var name = ""
    @State private var specialty = ""
    @State private var title = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var address = ""
    @State private var emergencyContact = ""
    @State private var bio = ""
    @State private var hourlyRate = ""
    @State private var experienceYears = ""
    @State private var imageURL = ""
    @State private var category: Caregiver.CareCategory = .all
    @State private var availability: [String] = [""]
    @State private var skills: [String] = [""]
    @State private var education: [String] = [""]
    @State private var certifications: [String] = [""]
    @State private var isSaving = false
    @State private var showSaved = false
    @State private var showError = false
    @State private var errorMessage = ""

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
                        formField("Professional Title", text: $title, icon: "cross.case")
                        formField("Specialty", text: $specialty, icon: "stethoscope")
                        formField("Email", text: $email, icon: "envelope.fill", keyboard: .emailAddress)
                        formField("Hourly Rate ($)", text: $hourlyRate, icon: "dollarsign.circle", keyboard: .decimalPad)
                        formField("Experience (years)", text: $experienceYears, icon: "clock.arrow.circlepath", keyboard: .numberPad)
                        formField("Phone Number", text: $phone, icon: "phone.fill", keyboard: .phonePad)
                        formField("Address", text: $address, icon: "house.fill")
                        formField("Emergency Contact", text: $emergencyContact, icon: "phone.badge.plus", keyboard: .phonePad)
                        formField("Profile Image URL", text: $imageURL, icon: "photo")
                        Picker("Category", selection: $category) {
                            ForEach(Caregiver.CareCategory.allCases, id: \.self) { item in
                                Text(item.rawValue).tag(item)
                            }
                        }
                        .pickerStyle(.menu)
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

                    formSection("Professional Details") {
                        dynamicRows(
                            title: "Skills",
                            icon: "checkmark.seal",
                            values: $skills,
                            addLabel: "Add Skill",
                            placeholder: "e.g. Wound care"
                        )
                        dynamicRows(
                            title: "Education",
                            icon: "graduationcap.fill",
                            values: $education,
                            addLabel: "Add Education",
                            placeholder: "e.g. BSc Nursing - XYZ University"
                        )
                        dynamicRows(
                            title: "Certifications",
                            icon: "rosette",
                            values: $certifications,
                            addLabel: "Add Certification",
                            placeholder: "e.g. BLS, ACLS"
                        )
                        dynamicRows(
                            title: "Availability",
                            icon: "calendar.badge.clock",
                            values: $availability,
                            addLabel: "Add Availability",
                            placeholder: "e.g. Monday 9:00-17:00"
                        )
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
            .alert("Profile update issue", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                // Load data asynchronously without blocking the UI.
                Task { await loadExistingProfile() }
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

    // Use a safe fallback when data is missing.
    private func formField(_ placeholder: String, text: Binding<String>, icon: String, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: CLTheme.spacingXS) {
            Text(placeholder.uppercased())
                .font(CLTheme.smallFont)
                .foregroundStyle(CLTheme.textTertiary)
                .tracking(1)
            CLTextField(placeholder: placeholder, text: text, icon: icon, keyboardType: keyboard)
        }
    }

    private func dynamicRows(
        title: String,
        icon: String,
        values: Binding<[String]>,
        addLabel: String,
        placeholder: String
    ) -> some View {
        VStack(alignment: .leading, spacing: CLTheme.spacingSM) {
            Text(title.uppercased())
                .font(CLTheme.smallFont)
                .foregroundStyle(CLTheme.textTertiary)
                .tracking(1)

            ForEach(Array(values.wrappedValue.enumerated()), id: \.offset) { index, _ in
                HStack(spacing: CLTheme.spacingSM) {
                    CLTextField(
                        placeholder: placeholder,
                        text: Binding(
                            get: { values.wrappedValue[index] },
                            set: { values.wrappedValue[index] = $0 }
                        ),
                        icon: icon
                    )
                    if values.wrappedValue.count > 1 {
                        Button {
                            values.wrappedValue.remove(at: index)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(CLTheme.errorRed)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button {
                values.wrappedValue.append("")
            } label: {
                Label(addLabel, systemImage: "plus.circle.fill")
                    .font(CLTheme.calloutFont)
                    .foregroundStyle(CLTheme.accentBlue)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }

    private func saveProfile() {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSpecialty = specialty.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanBio = bio.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEmergencyContact = emergencyContact.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanImageURL = imageURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let parsedRate = Double(hourlyRate.trimmingCharacters(in: .whitespacesAndNewlines)) ?? -1
        let parsedExperience = Int(experienceYears.trimmingCharacters(in: .whitespacesAndNewlines)) ?? -1
        let cleanSkills = skills.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let cleanEducation = education.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let cleanCertifications = certifications.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let cleanAvailability = availability.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }

        guard !cleanName.isEmpty else { return presentValidation("Full name is required.") }
        guard !cleanTitle.isEmpty else { return presentValidation("Professional title is required.") }
        guard !cleanSpecialty.isEmpty else { return presentValidation("Specialty is required.") }
        guard cleanEmail.contains("@"), cleanEmail.contains(".") else { return presentValidation("Please enter a valid email.") }
        guard parsedRate >= 0 else { return presentValidation("Please enter a valid hourly rate.") }
        guard parsedExperience >= 0 else { return presentValidation("Please enter valid years of experience.") }
        guard cleanPhone.filter(\.isNumber).count >= 7 else { return presentValidation("Please enter a valid phone number.") }
        if !cleanEmergencyContact.isEmpty, cleanEmergencyContact.filter(\.isNumber).count < 7 {
            return presentValidation("Emergency contact number looks incomplete.")
        }
        guard cleanBio.count >= 20 else { return presentValidation("Bio should be at least 20 characters.") }
        guard !cleanSkills.isEmpty else { return presentValidation("Add at least one skill.") }
        guard !cleanEducation.isEmpty else { return presentValidation("Add at least one education entry.") }
        guard !cleanAvailability.isEmpty else { return presentValidation("Add at least one availability entry.") }

        isSaving = true
        Task {
            let uid = appState.authService.currentUser?.uid ?? UUID().uuidString
            let existing = viewModel.caregiverProfile
            let caregiver = Caregiver(
                id: existing?.id ?? uid,
                userId: uid,
                name: cleanName,
                specialty: cleanSpecialty,
                title: cleanTitle,
                hourlyRate: parsedRate,
                rating: existing?.rating ?? 0,
                reviewCount: existing?.reviewCount ?? 0,
                experienceYears: parsedExperience,
                distance: existing?.distance ?? 0,
                bio: cleanBio,
                skills: cleanSkills,
                education: cleanEducation,
                certifications: cleanCertifications,
                availability: cleanAvailability,
                imageURL: cleanImageURL,
                latitude: existing?.latitude ?? 0,
                longitude: existing?.longitude ?? 0,
                isVerified: existing?.isVerified ?? false,
                category: category,
                phoneNumber: cleanPhone,
                email: cleanEmail
            )
            await viewModel.updateProfile(caregiver: caregiver, firestoreService: appState.firestoreService)
            await MainActor.run {
                isSaving = false
                if let message = viewModel.errorMessage, !message.isEmpty {
                    errorMessage = message
                    showError = true
                    return
                }
                showSaved = true
            }
            if var user = appState.authService.userProfile {
                user.fullName = cleanName
                user.email = cleanEmail
                user.phoneNumber = cleanPhone
                user.address = cleanAddress
                user.emergencyContact = cleanEmergencyContact
                user.profileImageURL = cleanImageURL
                try? await appState.authService.updateUserProfile(user)
            }
            try? await Task.sleep(for: .seconds(1.4))
            await MainActor.run {
                showSaved = false
                dismiss()
            }
        }
    }

    private func loadExistingProfile() async {
        let uid = appState.authService.currentUser?.uid ?? ""
        guard !uid.isEmpty else { return }

        let userProfile = appState.authService.userProfile
        name = userProfile?.fullName ?? ""
        email = userProfile?.email ?? ""
        phone = userProfile?.phoneNumber ?? ""
        address = userProfile?.address ?? ""
        emergencyContact = userProfile?.emergencyContact ?? ""
        imageURL = userProfile?.profileImageURL ?? ""

        if let existing = try? await appState.firestoreService.fetchCaregiverByUserId(uid) {
            await MainActor.run {
                viewModel.caregiverProfile = existing
                name = existing.name
                specialty = existing.specialty
                title = existing.title
                bio = existing.bio
                hourlyRate = existing.hourlyRate > 0 ? String(format: "%.2f", existing.hourlyRate) : ""
                experienceYears = existing.experienceYears > 0 ? "\(existing.experienceYears)" : ""
                phone = existing.phoneNumber.isEmpty ? phone : existing.phoneNumber
                email = existing.email.isEmpty ? email : existing.email
                imageURL = existing.imageURL.isEmpty ? imageURL : existing.imageURL
                category = existing.category
                availability = existing.availability.isEmpty ? [""] : existing.availability
                skills = existing.skills.isEmpty ? [""] : existing.skills
                education = existing.education.isEmpty ? [""] : existing.education
                certifications = existing.certifications.isEmpty ? [""] : existing.certifications
            }
        }
    }

    private func presentValidation(_ message: String) {
        errorMessage = message
        showError = true
    }
}

#Preview {
    CaregiverProfileEditView()
        .environment(AppState())
}
