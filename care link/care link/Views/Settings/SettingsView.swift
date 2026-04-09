import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var notificationsEnabled = true
    @State private var biometricEnabled = false
    @State private var isSyncingBiometricToggle = false
    @State private var didInitializeBiometricToggle = false
    @State private var showBiometricInfoAlert = false
    @State private var biometricInfoMessage = ""
    @State private var fontSize: Double = 16
    @State private var showDeleteConfirmation = false
    @State private var showSignOutConfirmation = false
    @State private var showClearDataConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    settingsRow(icon: "bell.fill", title: "Push Notifications", color: CLTheme.accentBlue) {
                        Toggle("", isOn: $notificationsEnabled)
                            .tint(CLTheme.accentBlue)
                    }

                    settingsRow(icon: "faceid", title: "Biometric Login", color: CLTheme.tealAccent) {
                        Toggle("", isOn: $biometricEnabled)
                            .tint(CLTheme.tealAccent)
                            .disabled(!appState.biometricService.isAvailable)
                    }
                } header: {
                    Text("Security & Privacy")
                } footer: {
                    Text("After you sign in once and tap Enable, CareLink can unlock with Face ID, Touch ID, or your passcode each time you open the app (Simulator: set a device passcode or use Features → Face ID). Turn off to remove saved sign-in.")
                }

                Section {
                    settingsRow(icon: "textformat.size", title: "Font Size", color: CLTheme.warningOrange) {
                        Slider(value: $fontSize, in: 12...24, step: 1)
                            .frame(width: 120)
                            .tint(CLTheme.accentBlue)
                    }

                    settingsRow(icon: "moon.fill", title: "Dark Mode", color: CLTheme.primaryNavy) {
                        Toggle("", isOn: .constant(false))
                            .tint(CLTheme.primaryNavy)
                    }
                } header: {
                    Text("Accessibility")
                }

                Section {
                    settingsRow(icon: "questionmark.circle.fill", title: "Help & Support", color: CLTheme.accentBlue) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundStyle(CLTheme.textTertiary)
                    }

                    settingsRow(icon: "doc.text.fill", title: "Terms of Service", color: CLTheme.textSecondary) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundStyle(CLTheme.textTertiary)
                    }

                    settingsRow(icon: "lock.shield.fill", title: "Privacy Policy", color: CLTheme.textSecondary) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundStyle(CLTheme.textTertiary)
                    }
                } header: {
                    Text("About")
                }

                Section {
                    Button {
                        showSignOutConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .foregroundStyle(CLTheme.warningOrange)
                            Text("Sign Out")
                                .foregroundStyle(CLTheme.warningOrange)
                            Spacer()
                        }
                    }

                    Button {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "trash.fill")
                                .foregroundStyle(CLTheme.errorRed)
                            Text("Delete Account")
                                .foregroundStyle(CLTheme.errorRed)
                            Spacer()
                        }
                    }
                }

                Section("Developer") {
                    Button {
                        showClearDataConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "trash.circle.fill")
                                .foregroundStyle(CLTheme.errorRed)
                            Text("Clear All Data & Start Fresh")
                                .foregroundStyle(CLTheme.errorRed)
                            Spacer()
                        }
                    }

                    Button {
                        appState.resetOnboarding()
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundStyle(CLTheme.textSecondary)
                            Text("Reset Onboarding")
                                .foregroundStyle(CLTheme.textPrimary)
                            Spacer()
                        }
                    }
                }

                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            Text("CareLink v1.0")
                                .font(CLTheme.captionFont)
                                .foregroundStyle(CLTheme.textTertiary)
                            Text("Made with care")
                                .font(CLTheme.captionFont)
                                .foregroundStyle(CLTheme.textTertiary)
                        }
                        Spacer()
                    }
                }
                .listRowBackground(Color.clear)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(CLTheme.accentBlue)
                }
            }
            .alert("Sign Out", isPresented: $showSignOutConfirmation) {
                Button("Sign Out", role: .destructive) {
                    appState.signOut()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .alert("Clear All Data", isPresented: $showClearDataConfirmation) {
                Button("Clear Everything", role: .destructive) {
                    appState.clearAllData()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will sign you out, clear all local data, and reset the app to its initial state.")
            }
            .alert("Delete Account", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    Task {
                        try? await appState.authService.deleteAccount()
                        appState.signOut()
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This action cannot be undone. All your data will be permanently deleted.")
            }
            .alert("Biometric Login", isPresented: $showBiometricInfoAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(biometricInfoMessage)
            }
            .onAppear {
                appState.biometricService.checkAvailability()
                let localEnabled = UserDefaults.standard.bool(forKey: AppState.biometricAppUnlockPreferenceKey)
                let profileEnabled = appState.authService.userProfile?.isBiometricEnabled == true
                setBiometricToggle(localEnabled && profileEnabled)
                didInitializeBiometricToggle = true
            }
            .onChange(of: biometricEnabled) { _, newValue in
                guard didInitializeBiometricToggle, !isSyncingBiometricToggle else { return }
                let currentlyEnabled = UserDefaults.standard.bool(forKey: AppState.biometricAppUnlockPreferenceKey)
                    && appState.authService.userProfile?.isBiometricEnabled == true
                guard newValue != currentlyEnabled else { return }
                Task {
                    if newValue {
                        await handleEnableBiometricToggle()
                    } else {
                        await handleDisableBiometricToggle()
                    }
                }
            }
        }
    }

    @MainActor
    private func handleEnableBiometricToggle() async {
        guard appState.biometricService.isAvailable else {
            biometricInfoMessage = "Biometric authentication is not available on this device."
            showBiometricInfoAlert = true
            setBiometricToggle(false)
            return
        }
        guard var profile = appState.authService.userProfile else {
            biometricInfoMessage = "Your profile is still loading. Please try enabling biometric login again in a moment."
            showBiometricInfoAlert = true
            setBiometricToggle(false)
            return
        }

        let ok = await appState.biometricService.authenticate()
        guard ok else {
            setBiometricToggle(false)
            return
        }

        UserDefaults.standard.set(true, forKey: AppState.biometricAppUnlockPreferenceKey)
        profile.isBiometricEnabled = true
        try? await appState.firestoreService.updateUser(profile)
        await appState.authService.fetchUserProfile(uid: profile.id)
        setBiometricToggle(true)
    }

    @MainActor
    private func handleDisableBiometricToggle() async {
        BiometricCredentialStore.clear()
        appState.isBiometricAppLocked = false
        UserDefaults.standard.removeObject(forKey: AppState.biometricAppUnlockPreferenceKey)
        if var profile = appState.authService.userProfile {
            profile.isBiometricEnabled = false
            try? await appState.firestoreService.updateUser(profile)
            await appState.authService.fetchUserProfile(uid: profile.id)
        }
        setBiometricToggle(false)
    }

    @MainActor
    private func setBiometricToggle(_ enabled: Bool) {
        isSyncingBiometricToggle = true
        biometricEnabled = enabled
        isSyncingBiometricToggle = false
    }

    private func settingsRow<Accessory: View>(
        icon: String,
        title: String,
        color: Color,
        @ViewBuilder accessory: () -> Accessory
    ) -> some View {
        HStack(spacing: CLTheme.spacingMD) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
                .frame(width: 30, height: 30)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: CLTheme.cornerRadiusSM, style: .continuous))

            Text(title)
                .font(CLTheme.bodyFont)
                .foregroundStyle(CLTheme.textPrimary)

            Spacer()

            accessory()
        }
    }
}

#Preview {
    SettingsView()
        .environment(AppState())
}
