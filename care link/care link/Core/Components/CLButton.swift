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

    private var usesTallChrome: Bool {
        style != .text
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
                        .font(usesTallChrome ? CLTheme.headlineFont : CLTheme.calloutFont)
                }
            }
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .frame(height: usesTallChrome ? 56 : 44)
            .padding(.horizontal, usesTallChrome ? 0 : CLTheme.spacingMD)
            .foregroundStyle(foregroundColor)
            .background(background)
            .clipShape(Capsule())
            .overlay {
                if style == .outline {
                    Capsule()
                        .stroke(CLTheme.divider, lineWidth: 1.5)
                }
            }
            .shadow(
                color: style == .primary ? CLTheme.primaryNavy.opacity(0.22) : .clear,
                radius: style == .primary ? 12 : 0,
                x: 0,
                y: style == .primary ? 6 : 0
            )
        }
        .buttonStyle(CLPressableButtonStyle())
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

private struct CLPressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
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
