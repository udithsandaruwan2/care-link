import SwiftUI
import FirebaseAuth

struct EditProfileView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var fullName = ""
    @State private var address = ""
    @State private var emergencyContact = ""
    @State private var isSaving = false
    @State private var showSaved = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: CLTheme.spacingLG) {
                    avatarSection
                    formSection
                    phoneSection
                }
                .padding(.bottom, CLTheme.spacingXL)
            }
            .background(CLTheme.backgroundPrimary)
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(CLTheme.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        saveProfile()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(CLTheme.accentBlue)
                        }
                    }
                    .disabled(isSaving)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
            .overlay {
                if showSaved {
                    savedBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .onAppear { loadProfile() }
        }
    }

    // MARK: - Avatar

    private var avatarSection: some View {
        VStack(spacing: CLTheme.spacingSM) {
            ZStack {
                Circle()
                    .fill(CLTheme.primaryNavy.opacity(0.12))
                    .frame(width: 100, height: 100)
                Text(String(fullName.prefix(2)).uppercased())
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(CLTheme.primaryNavy)
            }

            Text(appState.currentUserRole == .caregiver ? "Caregiver" : "Patient")
                .font(CLTheme.captionFont)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(appState.currentUserRole == .caregiver ? CLTheme.tealAccent : CLTheme.accentBlue)
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(.top, CLTheme.spacingLG)
    }

    // MARK: - Form

    private var formSection: some View {
        VStack(spacing: CLTheme.spacingMD) {
            VStack(alignment: .leading, spacing: CLTheme.spacingXS) {
                Text("FULL NAME")
                    .font(CLTheme.smallFont)
                    .foregroundStyle(CLTheme.textTertiary)
                    .tracking(1)
                CLTextField(placeholder: "Your full name", text: $fullName, icon: "person.fill")
            }

            VStack(alignment: .leading, spacing: CLTheme.spacingXS) {
                Text("ADDRESS")
                    .font(CLTheme.smallFont)
                    .foregroundStyle(CLTheme.textTertiary)
                    .tracking(1)
                CLTextField(placeholder: "Your home address", text: $address, icon: "house.fill")
            }

            VStack(alignment: .leading, spacing: CLTheme.spacingXS) {
                Text("EMERGENCY CONTACT")
                    .font(CLTheme.smallFont)
                    .foregroundStyle(CLTheme.textTertiary)
                    .tracking(1)
                CLTextField(placeholder: "Emergency phone number", text: $emergencyContact, icon: "phone.badge.plus", keyboardType: .phonePad)
            }
        }
        .padding(CLTheme.spacingMD)
        .background(CLTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: CLTheme.cornerRadiusLG))
        .shadow(color: CLTheme.shadowLight, radius: 4)
        .padding(.horizontal, CLTheme.spacingMD)
    }

    // MARK: - Email (read only)

    private var phoneSection: some View {
        VStack(alignment: .leading, spacing: CLTheme.spacingXS) {
            Text("EMAIL")
                .font(CLTheme.smallFont)
                .foregroundStyle(CLTheme.textTertiary)
                .tracking(1)

            HStack(spacing: CLTheme.spacingSM) {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(CLTheme.tealAccent)
                    .frame(width: 24)
                Text(appState.authService.userProfile?.email ?? appState.authService.currentUser?.email ?? "—")
                    .font(CLTheme.bodyFont)
                    .foregroundStyle(CLTheme.textPrimary)
                Spacer()
                Image(systemName: "lock.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(CLTheme.textTertiary)
            }
            .padding(.horizontal, CLTheme.spacingMD)
            .frame(height: 54)
            .background(CLTheme.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: CLTheme.cornerRadiusMD))
        }
        .padding(.horizontal, CLTheme.spacingMD)
    }

    // MARK: - Saved Banner

    private var savedBanner: some View {
        VStack {
            HStack(spacing: CLTheme.spacingSM) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(CLTheme.successGreen)
                Text("Profile saved successfully")
                    .font(CLTheme.calloutFont)
                    .foregroundStyle(CLTheme.textPrimary)
            }
            .padding(.horizontal, CLTheme.spacingMD)
            .padding(.vertical, CLTheme.spacingSM)
            .background(CLTheme.successGreen.opacity(0.12))
            .clipShape(Capsule())
            .padding(.top, CLTheme.spacingMD)
            Spacer()
        }
    }

    // MARK: - Logic

    private func loadProfile() {
        guard let profile = appState.authService.userProfile else { return }
        fullName = profile.fullName
        address = profile.address
        emergencyContact = profile.emergencyContact
    }

    private func saveProfile() {
        guard !fullName.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Name cannot be empty."
            showError = true
            return
        }

        isSaving = true
        Task {
            guard var profile = appState.authService.userProfile else { return }
            profile.fullName = fullName.trimmingCharacters(in: .whitespaces)
            profile.address = address.trimmingCharacters(in: .whitespaces)
            profile.emergencyContact = emergencyContact.trimmingCharacters(in: .whitespaces)

            do {
                try await appState.authService.updateUserProfile(profile)
                await MainActor.run {
                    withAnimation { showSaved = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
            await MainActor.run { isSaving = false }
        }
    }
}

#Preview {
    EditProfileView()
        .environment(AppState())
}
