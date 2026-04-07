import SwiftUI

struct CLTextField: View {
    let placeholder: String
    @Binding var text: String
    var icon: String? = nil
    var isSecure: Bool = false
    var trailingText: String? = nil
    var trailingAction: (() -> Void)? = nil
    var keyboardType: UIKeyboardType = .default

    @State private var isPasswordVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: CLTheme.spacingXS) {
            HStack(spacing: CLTheme.spacingSM) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundStyle(CLTheme.textTertiary)
                        .frame(width: 24)
                }

                if isSecure && !isPasswordVisible {
                    SecureField(placeholder, text: $text)
                        .font(CLTheme.bodyFont)
                } else {
                    TextField(placeholder, text: $text)
                        .font(CLTheme.bodyFont)
                        .keyboardType(keyboardType)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                if isSecure {
                    Button {
                        isPasswordVisible.toggle()
                    } label: {
                        Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                            .font(.system(size: 14))
                            .foregroundStyle(CLTheme.textTertiary)
                    }
                }

                if let trailingText {
                    Button {
                        trailingAction?()
                    } label: {
                        Text(trailingText)
                            .font(CLTheme.calloutFont)
                            .foregroundStyle(CLTheme.accentBlue)
                    }
                }
            }
            .padding(.horizontal, CLTheme.spacingMD)
            .frame(height: 54)
            .background(CLTheme.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: CLTheme.cornerRadiusMD))
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
