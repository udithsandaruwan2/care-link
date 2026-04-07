import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var notificationsEnabled = true
    @State private var biometricEnabled = false
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
                    }
                } header: {
                    Text("Security & Privacy")
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
        }
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
                .frame(width: 28, height: 28)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))

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
