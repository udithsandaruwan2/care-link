import SwiftUI
import UIKit

enum CLTheme {
    private static let colorBlindModeKey = "carelink.colorBlindMode"
    private static let highContrastKey = "carelink.highContrastMode"

    enum ColorBlindMode: String, CaseIterable {
        case off
        case protanopia
        case deuteranopia
        case tritanopia
    }

    private static var selectedColorBlindMode: ColorBlindMode {
        let stored = UserDefaults.standard.string(forKey: colorBlindModeKey) ?? ColorBlindMode.off.rawValue
        return ColorBlindMode(rawValue: stored) ?? .off
    }

    private static var highContrastEnabled: Bool {
        UserDefaults.standard.bool(forKey: highContrastKey)
    }

    private static func colorForMode(
        default light: UIColor,
        protanopia: UIColor,
        deuteranopia: UIColor,
        tritanopia: UIColor
    ) -> UIColor {
        switch selectedColorBlindMode {
        case .off:
            return light
        case .protanopia:
            return protanopia
        case .deuteranopia:
            return deuteranopia
        case .tritanopia:
            return tritanopia
        }
    }

    private static func darkColorForMode(
        default dark: UIColor,
        protanopia: UIColor,
        deuteranopia: UIColor,
        tritanopia: UIColor
    ) -> UIColor {
        switch selectedColorBlindMode {
        case .off:
            return dark
        case .protanopia:
            return protanopia
        case .deuteranopia:
            return deuteranopia
        case .tritanopia:
            return tritanopia
        }
    }

    private static func applyContrast(_ color: UIColor, darkenBy amount: CGFloat = 0.08) -> UIColor {
        guard highContrastEnabled else { return color }
        return color.withSaturationAdjusted(multiplier: 1.15).withBrightnessAdjusted(delta: -amount)
    }

    // MARK: - Colors
    static let primaryNavy = Color(uiColor: UIColor { trait in
        let light = UIColor(red: 0.00, green: 0.20, blue: 0.40, alpha: 1.0)
        let dark = UIColor(red: 0.52, green: 0.73, blue: 0.98, alpha: 1.0)
        let modeLight = colorForMode(
            default: light,
            protanopia: UIColor(red: 0.06, green: 0.22, blue: 0.45, alpha: 1.0),
            deuteranopia: UIColor(red: 0.10, green: 0.23, blue: 0.48, alpha: 1.0),
            tritanopia: UIColor(red: 0.08, green: 0.16, blue: 0.40, alpha: 1.0)
        )
        let modeDark = darkColorForMode(
            default: dark,
            protanopia: UIColor(red: 0.63, green: 0.79, blue: 0.98, alpha: 1.0),
            deuteranopia: UIColor(red: 0.60, green: 0.80, blue: 0.98, alpha: 1.0),
            tritanopia: UIColor(red: 0.58, green: 0.76, blue: 0.99, alpha: 1.0)
        )
        return applyContrast(trait.userInterfaceStyle == .dark ? modeDark : modeLight)
    })
    static let accentBlue = Color(uiColor: UIColor { trait in
        let light = UIColor(red: 0.00, green: 0.40, blue: 0.80, alpha: 1.0)
        let dark = UIColor(red: 0.34, green: 0.62, blue: 0.98, alpha: 1.0)
        let modeLight = colorForMode(
            default: light,
            protanopia: UIColor(red: 0.09, green: 0.45, blue: 0.68, alpha: 1.0),
            deuteranopia: UIColor(red: 0.05, green: 0.47, blue: 0.70, alpha: 1.0),
            tritanopia: UIColor(red: 0.32, green: 0.30, blue: 0.82, alpha: 1.0)
        )
        let modeDark = darkColorForMode(
            default: dark,
            protanopia: UIColor(red: 0.43, green: 0.76, blue: 0.93, alpha: 1.0),
            deuteranopia: UIColor(red: 0.42, green: 0.78, blue: 0.92, alpha: 1.0),
            tritanopia: UIColor(red: 0.56, green: 0.56, blue: 0.97, alpha: 1.0)
        )
        return applyContrast(trait.userInterfaceStyle == .dark ? modeDark : modeLight)
    })
    static let lightBlue = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.12, green: 0.21, blue: 0.36, alpha: 1.0)
            : UIColor(red: 0.91, green: 0.94, blue: 0.99, alpha: 1.0)
    })
    static let tealAccent = Color(uiColor: UIColor { _ in
        let base = colorForMode(
            default: UIColor(red: 0.05, green: 0.58, blue: 0.53, alpha: 1.0),
            protanopia: UIColor(red: 0.00, green: 0.50, blue: 0.63, alpha: 1.0),
            deuteranopia: UIColor(red: 0.00, green: 0.52, blue: 0.61, alpha: 1.0),
            tritanopia: UIColor(red: 0.24, green: 0.44, blue: 0.88, alpha: 1.0)
        )
        return applyContrast(base)
    })
    static let successGreen = Color(uiColor: UIColor { _ in
        let base = colorForMode(
            default: UIColor(red: 0.09, green: 0.64, blue: 0.29, alpha: 1.0),
            protanopia: UIColor(red: 0.00, green: 0.47, blue: 0.70, alpha: 1.0),
            deuteranopia: UIColor(red: 0.00, green: 0.50, blue: 0.66, alpha: 1.0),
            tritanopia: UIColor(red: 0.32, green: 0.30, blue: 0.82, alpha: 1.0)
        )
        return applyContrast(base)
    })
    static let warningOrange = Color(uiColor: UIColor { _ in
        let base = colorForMode(
            default: UIColor(red: 0.96, green: 0.62, blue: 0.04, alpha: 1.0),
            protanopia: UIColor(red: 0.80, green: 0.54, blue: 0.12, alpha: 1.0),
            deuteranopia: UIColor(red: 0.82, green: 0.50, blue: 0.15, alpha: 1.0),
            tritanopia: UIColor(red: 0.84, green: 0.40, blue: 0.16, alpha: 1.0)
        )
        return applyContrast(base)
    })
    static let errorRed = Color(uiColor: UIColor { _ in
        let base = colorForMode(
            default: UIColor(red: 0.86, green: 0.15, blue: 0.15, alpha: 1.0),
            protanopia: UIColor(red: 0.58, green: 0.36, blue: 0.14, alpha: 1.0),
            deuteranopia: UIColor(red: 0.56, green: 0.33, blue: 0.16, alpha: 1.0),
            tritanopia: UIColor(red: 0.62, green: 0.22, blue: 0.34, alpha: 1.0)
        )
        return applyContrast(base, darkenBy: 0.05)
    })
    static let backgroundPrimary = Color(uiColor: .systemBackground)
    static let backgroundSecondary = Color(uiColor: .secondarySystemBackground)
    static let cardBackground = Color(uiColor: .tertiarySystemBackground)
    static let textPrimary = Color(uiColor: .label)
    static let textSecondary = Color(uiColor: .secondaryLabel)
    static let textTertiary = Color(uiColor: .tertiaryLabel)
    static let divider = Color(uiColor: .separator)
    static let starYellow = Color(uiColor: UIColor { _ in
        let base = colorForMode(
            default: UIColor(red: 0.96, green: 0.62, blue: 0.04, alpha: 1.0),
            protanopia: UIColor(red: 0.76, green: 0.56, blue: 0.18, alpha: 1.0),
            deuteranopia: UIColor(red: 0.78, green: 0.52, blue: 0.17, alpha: 1.0),
            tritanopia: UIColor(red: 0.86, green: 0.42, blue: 0.18, alpha: 1.0)
        )
        return applyContrast(base)
    })

    static let gradientBlue = LinearGradient(
        colors: [
            Color(uiColor: UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(red: 0.08, green: 0.20, blue: 0.35, alpha: 1.0)
                    : UIColor(red: 0.00, green: 0.25, blue: 0.50, alpha: 1.0)
            }),
            Color(uiColor: UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(red: 0.10, green: 0.33, blue: 0.60, alpha: 1.0)
                    : UIColor(red: 0.00, green: 0.40, blue: 0.80, alpha: 1.0)
            })
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    // MARK: - Typography (Dynamic Type–friendly semantic styles)
    static let largeTitleFont = Font.largeTitle.weight(.bold)
    static let titleFont = Font.title.weight(.bold)
    static let title2Font = Font.title2.weight(.semibold)
    static let headlineFont = Font.headline
    static let bodyFont = Font.body
    static let calloutFont = Font.callout.weight(.medium)
    static let captionFont = Font.caption
    static let smallFont = Font.caption2.weight(.medium)

    // MARK: - Spacing
    static let spacingXS: CGFloat = 4
    static let spacingSM: CGFloat = 8
    static let spacingMD: CGFloat = 16
    static let spacingLG: CGFloat = 24
    static let spacingXL: CGFloat = 32
    static let spacingXXL: CGFloat = 48

    // MARK: - Corner Radius (softer, more “app-native” curves)
    static let cornerRadiusSM: CGFloat = 10
    static let cornerRadiusMD: CGFloat = 16
    static let cornerRadiusLG: CGFloat = 22
    static let cornerRadiusXL: CGFloat = 28
    static let cornerRadiusFull: CGFloat = 50
    /// Large marketing / hero panels on welcome & onboarding.
    static let cornerRadiusHero: CGFloat = 32

    /// Continuous corners read smoother than default on cards and sheets.
    static func continuousRect(cornerRadius: CGFloat) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    // MARK: - Shadow
    static let shadowLight = Color.black.opacity(0.14)
    static let shadowMedium = Color.black.opacity(0.2)
    static let shadowHeavy = Color.black.opacity(0.28)
}

private extension UIColor {
    func withBrightnessAdjusted(delta: CGFloat) -> UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        guard getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else { return self }
        return UIColor(
            hue: hue,
            saturation: saturation,
            brightness: max(0, min(1, brightness + delta)),
            alpha: alpha
        )
    }

    func withSaturationAdjusted(multiplier: CGFloat) -> UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        guard getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else { return self }
        return UIColor(
            hue: hue,
            saturation: max(0, min(1, saturation * multiplier)),
            brightness: brightness,
            alpha: alpha
        )
    }
}
