import SwiftUI

struct CLButton: View {
    let title: String
    var icon: String? = nil
    var style: ButtonStyle = .primary
    var isFullWidth: Bool = true
    var isLoading: Bool = false
    let action: () -> Void

    enum ButtonStyle {
        case primary
        case secondary
        case outline
        case text
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: CLTheme.spacingSM) {
                if isLoading {
                    ProgressView()
                        .tint(style == .primary ? .white : CLTheme.accentBlue)
                } else {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    Text(title)
                        .font(CLTheme.headlineFont)
                }
            }
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .frame(height: 54)
            .foregroundStyle(foregroundColor)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: CLTheme.cornerRadiusFull))
            .overlay {
                if style == .outline {
                    RoundedRectangle(cornerRadius: CLTheme.cornerRadiusFull)
                        .stroke(CLTheme.divider, lineWidth: 1.5)
                }
            }
        }
        .disabled(isLoading)
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .primary:
            CLTheme.gradientBlue
        case .secondary:
            CLTheme.backgroundSecondary
        case .outline:
            Color.clear
        case .text:
            Color.clear
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary:
            return .white
        case .secondary:
            return CLTheme.textPrimary
        case .outline:
            return CLTheme.accentBlue
        case .text:
            return CLTheme.accentBlue
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        CLButton(title: "Get Started", icon: "arrow.right", action: {})
        CLButton(title: "Sign In", style: .outline, action: {})
        CLButton(title: "Back to Home", style: .secondary, action: {})
        CLButton(title: "Loading...", isLoading: true, action: {})
    }
    .padding()
}
