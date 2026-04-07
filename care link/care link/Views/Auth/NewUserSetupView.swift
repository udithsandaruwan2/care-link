import SwiftUI
import FirebaseAuth

struct NewUserSetupView: View {
    @Environment(AppState.self) private var appState
    @State private var currentStep = 0
    @State private var fullName = ""
    @State private var address = ""
    @State private var emergencyContact = ""
    @State private var selectedRole: CLUser.UserRole = .user
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var animateIn = false

    private let totalSteps = 2

    var body: some View {
        VStack(spacing: 0) {
            header
            stepIndicator

            TabView(selection: $currentStep) {
                personalInfoStep.tag(0)
                roleStep.tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: currentStep)

            bottomBar
        }
        .background(CLTheme.backgroundPrimary)
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                animateIn = true
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: CLTheme.spacingSM) {
            ZStack {
                Circle()
                    .fill(CLTheme.tealAccent.opacity(0.15))
                    .frame(width: 72, height: 72)
                    .scaleEffect(animateIn ? 1 : 0.5)
                Image(systemName: "person.text.rectangle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(CLTheme.tealAccent)
                    .scaleEffect(animateIn ? 1 : 0.3)
            }

            Text("Complete Your Profile")
                .font(CLTheme.titleFont)
                .foregroundStyle(CLTheme.primaryNavy)

            Text("Tell us about yourself to get started")
                .font(CLTheme.captionFont)
                .foregroundStyle(CLTheme.textSecondary)
        }
        .padding(.top, CLTheme.spacingLG)
        .padding(.bottom, CLTheme.spacingSM)
    }

    // MARK: - Steps

    private var stepIndicator: some View {
        HStack(spacing: CLTheme.spacingSM) {
            ForEach(0..<totalSteps, id: \.self) { step in
                HStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(step <= currentStep ? CLTheme.primaryNavy : CLTheme.backgroundSecondary)
                            .frame(width: 28, height: 28)
                        if step < currentStep {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                        } else {
                            Text("\(step + 1)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(step == currentStep ? .white : CLTheme.textTertiary)
                        }
                    }
                    Text(step == 0 ? "About You" : "Your Role")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(step <= currentStep ? CLTheme.primaryNavy : CLTheme.textTertiary)
                }

                if step < totalSteps - 1 {
                    Rectangle()
                        .fill(step < currentStep ? CLTheme.primaryNavy : CLTheme.backgroundSecondary)
                        .frame(height: 2)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, CLTheme.spacingXL)
        .padding(.vertical, CLTheme.spacingMD)
    }

    // MARK: - Step 1: Personal Info

    private var personalInfoStep: some View {
        ScrollView {
            VStack(spacing: CLTheme.spacingLG) {
                sectionCard {
                    VStack(spacing: CLTheme.spacingMD) {
                        VStack(alignment: .leading, spacing: CLTheme.spacingXS) {
                            Text("FULL NAME")
                                .font(CLTheme.smallFont)
                                .foregroundStyle(CLTheme.textTertiary)
                                .tracking(1)
                            CLTextField(
                                placeholder: "Enter your full name",
                                text: $fullName,
                                icon: "person.fill"
                            )
                        }

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
                                Text(appState.authService.currentUser?.email ?? "—")
                                    .font(CLTheme.bodyFont)
                                    .foregroundStyle(CLTheme.textPrimary)
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(CLTheme.successGreen)
                                    .font(.system(size: 16))
                            }
                            .padding(.horizontal, CLTheme.spacingMD)
                            .frame(height: 54)
                            .background(CLTheme.successGreen.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: CLTheme.cornerRadiusMD))
                        }

                        VStack(alignment: .leading, spacing: CLTheme.spacingXS) {
                            Text("ADDRESS (OPTIONAL)")
                                .font(CLTheme.smallFont)
                                .foregroundStyle(CLTheme.textTertiary)
                                .tracking(1)
                            CLTextField(
                                placeholder: "Your home address",
                                text: $address,
                                icon: "house.fill"
                            )
                        }

                        VStack(alignment: .leading, spacing: CLTheme.spacingXS) {
                            Text("EMERGENCY CONTACT (OPTIONAL)")
                                .font(CLTheme.smallFont)
                                .foregroundStyle(CLTheme.textTertiary)
                                .tracking(1)
                            CLTextField(
                                placeholder: "Emergency phone number",
                                text: $emergencyContact,
                                icon: "phone.badge.plus",
                                keyboardType: .phonePad
                            )
                        }
                    }
                }
            }
            .padding(.bottom, 100)
        }
    }

    // MARK: - Step 2: Role

    private var roleStep: some View {
        ScrollView {
            VStack(spacing: CLTheme.spacingLG) {
                sectionCard {
                    VStack(spacing: CLTheme.spacingMD) {
                        Text("How will you use CareLink?")
                            .font(CLTheme.headlineFont)
                            .foregroundStyle(CLTheme.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        roleCard(
                            role: .user,
                            icon: "person.fill",
                            title: "Patient",
                            description: "Find and book caregivers, manage appointments, and access medical records.",
                            features: ["Browse caregivers", "Book sessions", "Chat & connect", "Medical records"]
                        )

                        roleCard(
                            role: .caregiver,
                            icon: "stethoscope",
                            title: "Caregiver",
                            description: "Manage patients, accept bookings, and provide professional care services.",
                            features: ["Manage patients", "Accept bookings", "Set your rates", "Track earnings"]
                        )
                    }
                }
            }
            .padding(.bottom, 100)
        }
    }

    private func roleCard(role: CLUser.UserRole, icon: String, title: String, description: String, features: [String]) -> some View {
        let isSelected = selectedRole == role
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedRole = role }
        } label: {
            VStack(alignment: .leading, spacing: CLTheme.spacingMD) {
                HStack(spacing: CLTheme.spacingMD) {
                    ZStack {
                        Circle()
                            .fill(isSelected ? CLTheme.primaryNavy.opacity(0.15) : CLTheme.backgroundSecondary)
                            .frame(width: 48, height: 48)
                        Image(systemName: icon)
                            .font(.system(size: 22))
                            .foregroundStyle(isSelected ? CLTheme.primaryNavy : CLTheme.textTertiary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(CLTheme.headlineFont)
                            .foregroundStyle(isSelected ? CLTheme.primaryNavy : CLTheme.textPrimary)
                        Text(description)
                            .font(CLTheme.captionFont)
                            .foregroundStyle(CLTheme.textSecondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    ZStack {
                        Circle()
                            .stroke(isSelected ? CLTheme.primaryNavy : CLTheme.divider, lineWidth: 2)
                            .frame(width: 24, height: 24)
                        if isSelected {
                            Circle()
                                .fill(CLTheme.primaryNavy)
                                .frame(width: 14, height: 14)
                        }
                    }
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    ForEach(features, id: \.self) { feature in
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(isSelected ? CLTheme.tealAccent : CLTheme.textTertiary)
                            Text(feature)
                                .font(.system(size: 11))
                                .foregroundStyle(CLTheme.textSecondary)
                            Spacer()
                        }
                    }
                }
            }
            .padding(CLTheme.spacingMD)
            .background(isSelected ? CLTheme.lightBlue : CLTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: CLTheme.cornerRadiusLG))
            .overlay {
                RoundedRectangle(cornerRadius: CLTheme.cornerRadiusLG)
                    .stroke(isSelected ? CLTheme.primaryNavy : CLTheme.divider, lineWidth: isSelected ? 2 : 1)
            }
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: CLTheme.spacingMD) {
            if currentStep > 0 {
                Button {
                    withAnimation { currentStep -= 1 }
                } label: {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(CLTheme.calloutFont)
                    .foregroundStyle(CLTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(CLTheme.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: CLTheme.cornerRadiusFull))
                }
            }

            Button {
                if currentStep < totalSteps - 1 {
                    guard validateCurrentStep() else { return }
                    withAnimation { currentStep += 1 }
                } else {
                    saveProfile()
                }
            } label: {
                HStack {
                    if isSaving {
                        ProgressView().tint(.white)
                    } else {
                        Text(currentStep < totalSteps - 1 ? "Next" : "Get Started")
                            .font(CLTheme.headlineFont)
                        Image(systemName: currentStep < totalSteps - 1 ? "arrow.right" : "checkmark")
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(CLTheme.gradientBlue)
                .clipShape(RoundedRectangle(cornerRadius: CLTheme.cornerRadiusFull))
            }
            .disabled(isSaving)
        }
        .padding(.horizontal, CLTheme.spacingLG)
        .padding(.vertical, CLTheme.spacingMD)
        .background(CLTheme.cardBackground.shadow(color: CLTheme.shadowMedium, radius: 8, y: -2))
    }

    // MARK: - Helpers

    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: CLTheme.spacingMD) {
            content()
        }
        .padding(CLTheme.spacingMD)
        .background(CLTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: CLTheme.cornerRadiusLG))
        .shadow(color: CLTheme.shadowLight, radius: 4)
        .padding(.horizontal, CLTheme.spacingMD)
    }

    private func validateCurrentStep() -> Bool {
        if currentStep == 0 {
            let trimmed = fullName.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                errorMessage = "Please enter your full name."
                showError = true
                return false
            }
        }
        return true
    }

    private func saveProfile() {
        guard validateCurrentStep() else { return }
        isSaving = true

        Task {
            guard let user = appState.authService.currentUser else {
                await MainActor.run {
                    errorMessage = "Authentication error. Please try again."
                    showError = true
                    isSaving = false
                }
                return
            }

            let newUser = CLUser(
                id: user.uid,
                fullName: fullName.trimmingCharacters(in: .whitespaces),
                email: user.email ?? "",
                phoneNumber: user.phoneNumber ?? "",
                role: selectedRole,
                profileImageURL: user.photoURL?.absoluteString ?? "",
                address: address.trimmingCharacters(in: .whitespaces),
                emergencyContact: emergencyContact.trimmingCharacters(in: .whitespaces),
                createdAt: Date(),
                isBiometricEnabled: false,
                hasCompletedCaregiverRegistration: false
            )

            do {
                try await appState.firestoreService.createUser(newUser)
                appState.authService.userProfile = newUser

                await MainActor.run {
                    appState.currentUserRole = selectedRole
                    appState.needsProfileSetup = false
                    if selectedRole == .caregiver {
                        appState.needsCaregiverRegistration = true
                    }
                    appState.startChatListener()
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
    NewUserSetupView()
        .environment(AppState())
}
