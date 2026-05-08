// File responsibility: Defines settings view logic for the care link app.

import SwiftUI
import UserNotifications
import UIKit

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @AppStorage("carelink.darkModeEnabled") private var darkModeEnabled = false
    @AppStorage("carelink.pushNotificationsEnabled") private var pushNotificationsEnabled = false
    @AppStorage("carelink.healthKitSyncEnabled") private var healthKitSyncEnabled = false
    @AppStorage("carelink.highContrastMode") private var highContrastMode = false
    @AppStorage("carelink.colorBlindMode") private var colorBlindMode = "off"
    @State private var biometricEnabled = false
    @State private var isSyncingBiometricToggle = false
    @State private var didInitializeBiometricToggle = false
    @State private var showBiometricInfoAlert = false
    @State private var biometricInfoMessage = ""
    @State private var fontSize: Double = 16
    @State private var showDeleteConfirmation = false
    @State private var showSignOutConfirmation = false
    @State private var showClearDataConfirmation = false
    @State private var showSupportCenter = false
    @State private var showLearningCenter = false
    @State private var showPrivacyPolicy = false
    @State private var isConnectingHealth = false

    private let supportEmail = "support@carelink.app"

    var body: some View {
        NavigationStack {
            List {
                Section {
                    settingsRow(icon: "bell.fill", title: "Push Notifications", color: CLTheme.accentBlue) {
                        Toggle("", isOn: $pushNotificationsEnabled)
                            .labelsHidden()
                            .accessibilityLabel(String(localized: "Push notifications"))
                            .accessibilityHint(String(localized: "Turns booking and message alerts on or off"))
                            .tint(CLTheme.accentBlue)
                    }

                    settingsRow(icon: "faceid", title: "Biometric Login", color: CLTheme.tealAccent) {
                        Toggle("", isOn: $biometricEnabled)
                            .labelsHidden()
                            .accessibilityLabel(String(localized: "Biometric login"))
                            .accessibilityHint(String(localized: "Uses Face ID or Touch ID to unlock the app"))
                            .tint(CLTheme.tealAccent)
                            .disabled(!appState.biometricService.isAvailable)
                    }
                } header: {
                    Text("Security & Privacy")
                } footer: {
                    Text("Push notifications use Apple’s permission dialog the first time you turn them on. You can revoke access anytime in the iOS Settings app. After you sign in once and tap Enable for biometric login, CareLink can unlock with Face ID or Touch ID each time you open the app. Turn off biometric to remove saved sign-in.")
                }

                AccessibilitySettingsSection(
                    fontSize: $fontSize,
                    darkModeEnabled: $darkModeEnabled,
                    highContrastMode: $highContrastMode,
                    colorBlindMode: $colorBlindMode
                )

                Section {
                    settingsRow(icon: "applewatch", title: "Health Device Sync", color: CLTheme.tealAccent) {
                        Text(healthConnectionLabel)
                            .font(CLTheme.captionFont)
                            .foregroundStyle(appState.healthKitService.isAuthorized ? CLTheme.successGreen : CLTheme.textSecondary)
                    }

                    Button {
                        // Load data asynchronously without blocking the UI.
                        Task { await connectOrRefreshHealth() }
                    } label: {
                        HStack {
                            Image(systemName: appState.healthKitService.isAuthorized ? "arrow.clockwise.circle.fill" : "link.circle.fill")
                                .foregroundStyle(CLTheme.accentBlue)
                            Text(appState.healthKitService.isAuthorized ? "Refresh Health Data" : "Connect Health Data")
                                .foregroundStyle(CLTheme.textPrimary)
                            Spacer()
                            if isConnectingHealth || appState.healthKitService.isLoading {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isConnectingHealth || !appState.healthKitService.isAvailable)
                } header: {
                    Text("Devices")
                } footer: {
                    Text("CareLink reads health metrics through Apple Health. Your smartwatch app must sync to Apple Health for data to appear here.")
                }

                Section {
                    Button {
                        showSupportCenter = true
                    } label: {
                        settingsRow(icon: "questionmark.circle.fill", title: "Help & Support", color: CLTheme.accentBlue) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundStyle(CLTheme.textTertiary)
                        }
                    }
                    .buttonStyle(.plain)

                    settingsRow(icon: "doc.text.fill", title: "Terms of Service", color: CLTheme.textSecondary) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundStyle(CLTheme.textTertiary)
                    }

                    Button {
                        showLearningCenter = true
                    } label: {
                        settingsRow(icon: "graduationcap.fill", title: "Learning Center", color: CLTheme.warningOrange) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundStyle(CLTheme.textTertiary)
                        }
                    }
                    .buttonStyle(.plain)

                    Button {
                        showPrivacyPolicy = true
                    } label: {
                        settingsRow(icon: "lock.shield.fill", title: "Privacy Policy", color: CLTheme.textSecondary) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundStyle(CLTheme.textTertiary)
                        }
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text("About")
                } footer: {
                    Text("Need help? Email \(supportEmail).")
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
            .navigationDestination(isPresented: $showSupportCenter) {
                SupportCenterView()
            }
            .navigationDestination(isPresented: $showLearningCenter) {
                LearningCenterView()
            }
            .navigationDestination(isPresented: $showPrivacyPolicy) {
                PrivacyPolicyView()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(CLTheme.accentBlue)
                        .accessibilityHint(String(localized: "Closes settings"))
                        .careLinkMinimumTapTarget(44)
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
                    // Load data asynchronously without blocking the UI.
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
                Task {
                    await appState.healthKitService.refreshAuthorizationStatus()
                    if healthKitSyncEnabled {
                        await appState.healthKitService.refreshMetrics()
                    }
                }
                Task {
                    let settings = await UNUserNotificationCenter.current().notificationSettings()
                    await MainActor.run {
                        appState.notificationService.isAuthorized = (settings.authorizationStatus == .authorized)
                    }
                }
                appState.biometricService.checkAvailability()
                let localEnabled = UserDefaults.standard.bool(forKey: AppState.biometricAppUnlockPreferenceKey)
                let profileEnabled = appState.authService.userProfile?.isBiometricEnabled == true
                setBiometricToggle(localEnabled && profileEnabled)
                didInitializeBiometricToggle = true
            }
            .onChange(of: pushNotificationsEnabled) { _, enabled in
                Task { @MainActor in
                    if enabled {
                        await appState.notificationService.requestAuthorization()
                        let settings = await UNUserNotificationCenter.current().notificationSettings()
                        let ok = settings.authorizationStatus == .authorized
                        appState.notificationService.isAuthorized = ok
                        if !ok {
                            pushNotificationsEnabled = false
                        }
                    } else {
                        appState.notificationService.isAuthorized = false
                    }
                }
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

    private var healthConnectionLabel: String {
        guard appState.healthKitService.isAvailable else { return "Unavailable" }
        return appState.healthKitService.isAuthorized ? "Connected" : "Not Connected"
    }

    @MainActor
    private func connectOrRefreshHealth() async {
        guard appState.healthKitService.isAvailable else {
            biometricInfoMessage = "Health access is not available on this device."
            showBiometricInfoAlert = true
            healthKitSyncEnabled = false
            return
        }
        isConnectingHealth = true
        defer { isConnectingHealth = false }

        if !appState.healthKitService.isAuthorized {
            let granted = await appState.healthKitService.requestAuthorization()
            healthKitSyncEnabled = granted
            if !granted {
                biometricInfoMessage = appState.healthKitService.lastErrorMessage ?? "Could not connect to Apple Health."
                showBiometricInfoAlert = true
                return
            }
        }

        await appState.healthKitService.refreshMetrics()
        healthKitSyncEnabled = appState.healthKitService.isAuthorized
    }

}

private struct AccessibilitySettingsSection: View {
    @Binding var fontSize: Double
    @Binding var darkModeEnabled: Bool
    @Binding var highContrastMode: Bool
    @Binding var colorBlindMode: String
    @State private var showAccessibilityHelpAlert = false

    var body: some View {
        Section {
            row(icon: "textformat.size", title: "Font Size", color: CLTheme.warningOrange) {
                Slider(value: $fontSize, in: 12...24, step: 1)
                    .frame(width: 120)
                    .tint(CLTheme.accentBlue)
                    .accessibilityLabel(String(localized: "Font size preview"))
                    .accessibilityHint(String(localized: "Adjusts demo font size in this settings screen only"))
            }

            row(icon: "moon.fill", title: "Dark Mode", color: CLTheme.primaryNavy) {
                Toggle("", isOn: $darkModeEnabled)
                    .labelsHidden()
                    .accessibilityLabel(String(localized: "Dark mode"))
                    .accessibilityHint(String(localized: "Uses a dark color scheme in the app"))
                    .tint(CLTheme.primaryNavy)
            }

            row(icon: "circle.lefthalf.filled", title: "High Contrast", color: CLTheme.primaryNavy) {
                Toggle("", isOn: $highContrastMode)
                    .labelsHidden()
                    .accessibilityLabel(String(localized: "High contrast mode"))
                    .accessibilityHint(String(localized: "Increases visual contrast for text and controls"))
                    .tint(CLTheme.primaryNavy)
            }

            row(icon: "eyedropper.halffull", title: "Color Blind Mode", color: CLTheme.accentBlue) {
                Picker("Color Blind Mode", selection: $colorBlindMode) {
                    Text("Off").tag("off")
                    Text("Protanopia").tag("protanopia")
                    Text("Deuteranopia").tag("deuteranopia")
                    Text("Tritanopia").tag("tritanopia")
                }
                .pickerStyle(.menu)
                .accessibilityLabel(String(localized: "Color blind mode"))
                .accessibilityHint(String(localized: "Adjusts app colors for common color vision deficiencies"))
            }

            Button {
                showAccessibilityHelpAlert = true
            } label: {
                row(icon: "speaker.wave.2.fill", title: "How to enable VoiceOver", color: CLTheme.tealAccent) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(CLTheme.textTertiary)
                }
            }
            .buttonStyle(.plain)
        } header: {
            Text("Accessibility")
        } footer: {
            Text("These accessibility preferences apply on this device for both patient and caregiver accounts.")
        }
        .alert("Enable VoiceOver", isPresented: $showAccessibilityHelpAlert) {
            Button("Open iOS Settings") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
            Button("Close", role: .cancel) {}
        } message: {
            Text("On iPhone: Settings > Accessibility > VoiceOver. Turn VoiceOver on, then use the same gesture navigation inside CareLink.")
        }
    }

    private func row<Accessory: View>(
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
