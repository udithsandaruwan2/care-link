// File responsibility: Defines c l text field logic for the care link app.

import SwiftUI

struct CLTextField: View {
    let placeholder: String
    @Binding var text: String
    var icon: String? = nil
    var isSecure: Bool = false
    var trailingText: String? = nil
    var trailingAction: (() -> Void)? = nil
    // Use a safe fallback when data is missing.
    var keyboardType: UIKeyboardType = .default
    // Use a safe fallback when data is missing.
    /// VoiceOver field name; defaults to `placeholder` when nil.
    var accessibilityFieldLabel: String? = nil

    @State private var isPasswordVisible = false

    private var fieldAccessibilityLabel: String {
        accessibilityFieldLabel ?? placeholder
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CLTheme.spacingXS) {
            HStack(spacing: CLTheme.spacingSM) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundStyle(CLTheme.textTertiary)
                        .frame(width: 24)
                        .accessibilityHidden(true)
                }

                if isSecure && !isPasswordVisible {
                    SecureField(placeholder, text: $text)
                        .font(CLTheme.bodyFont)
                        .accessibilityLabel(fieldAccessibilityLabel)
                } else {
                    TextField(placeholder, text: $text)
                        .font(CLTheme.bodyFont)
                        .keyboardType(keyboardType)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityLabel(fieldAccessibilityLabel)
                }

                if isSecure {
                    Button {
                        isPasswordVisible.toggle()
                    } label: {
                        Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                            .font(.system(size: 14))
                            .foregroundStyle(CLTheme.textTertiary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel(isPasswordVisible ? String(localized: "Hide password") : String(localized: "Show password"))
                }

                if let trailingText {
                    Button {
                        trailingAction?()
                    } label: {
                        Text(trailingText)
                            .font(CLTheme.calloutFont)
                            .foregroundStyle(CLTheme.accentBlue)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel(trailingText)
                    .accessibilityAddTraits(.isButton)
                }
            }
            .padding(.horizontal, CLTheme.spacingMD)
            .frame(minHeight: 54)
            .background(CLTheme.backgroundSecondary)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(CLTheme.divider.opacity(0.6), lineWidth: 1)
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        CLTextField(placeholder: "name@example.com", text: .constant(""), icon: "envelope")
        CLTextField(placeholder: "Password", text: .constant(""), icon: "lock", isSecure: true, trailingText: "Forgot?")
    }
    .padding()
}
