import SwiftUI
import UIKit

enum CLTheme {
    // MARK: - Colors
    static let primaryNavy = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.52, green: 0.73, blue: 0.98, alpha: 1.0)
            : UIColor(red: 0.00, green: 0.20, blue: 0.40, alpha: 1.0)
    })
    static let accentBlue = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.34, green: 0.62, blue: 0.98, alpha: 1.0)
            : UIColor(red: 0.00, green: 0.40, blue: 0.80, alpha: 1.0)
    })
    static let lightBlue = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.12, green: 0.21, blue: 0.36, alpha: 1.0)
            : UIColor(red: 0.91, green: 0.94, blue: 0.99, alpha: 1.0)
    })
    static let tealAccent = Color(hex: "0D9488")
    static let successGreen = Color(hex: "16A34A")
    static let warningOrange = Color(hex: "F59E0B")
    static let errorRed = Color(hex: "DC2626")
    static let backgroundPrimary = Color(uiColor: .systemBackground)
    static let backgroundSecondary = Color(uiColor: .secondarySystemBackground)
    static let cardBackground = Color(uiColor: .tertiarySystemBackground)
    static let textPrimary = Color(uiColor: .label)
    static let textSecondary = Color(uiColor: .secondaryLabel)
    static let textTertiary = Color(uiColor: .tertiaryLabel)
    static let divider = Color(uiColor: .separator)
    static let starYellow = Color(hex: "F59E0B")

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

    // MARK: - Typography
    static let largeTitleFont = Font.system(size: 32, weight: .bold, design: .rounded)
    static let titleFont = Font.system(size: 24, weight: .bold, design: .rounded)
    static let title2Font = Font.system(size: 20, weight: .semibold)
    static let headlineFont = Font.system(size: 17, weight: .semibold)
    static let bodyFont = Font.system(size: 16, weight: .regular)
    static let calloutFont = Font.system(size: 14, weight: .medium)
    static let captionFont = Font.system(size: 12, weight: .regular)
    static let smallFont = Font.system(size: 10, weight: .medium)

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
