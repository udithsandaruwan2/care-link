import SwiftUI

enum CLTheme {
    // MARK: - Colors
    static let primaryNavy = Color(hex: "003366")
    static let accentBlue = Color(hex: "0066CC")
    static let lightBlue = Color(hex: "E8F0FE")
    static let tealAccent = Color(hex: "0D9488")
    static let successGreen = Color(hex: "16A34A")
    static let warningOrange = Color(hex: "F59E0B")
    static let errorRed = Color(hex: "DC2626")
    static let backgroundPrimary = Color(hex: "F8FAFC")
    static let backgroundSecondary = Color(hex: "F1F5F9")
    static let cardBackground = Color.white
    static let textPrimary = Color(hex: "1E293B")
    static let textSecondary = Color(hex: "64748B")
    static let textTertiary = Color(hex: "94A3B8")
    static let divider = Color(hex: "E2E8F0")
    static let starYellow = Color(hex: "F59E0B")

    static let gradientBlue = LinearGradient(
        colors: [Color(hex: "004080"), Color(hex: "0066CC")],
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

    // MARK: - Corner Radius
    static let cornerRadiusSM: CGFloat = 8
    static let cornerRadiusMD: CGFloat = 12
    static let cornerRadiusLG: CGFloat = 16
    static let cornerRadiusXL: CGFloat = 20
    static let cornerRadiusFull: CGFloat = 50

    // MARK: - Shadow
    static let shadowLight = Color.black.opacity(0.05)
    static let shadowMedium = Color.black.opacity(0.1)
    static let shadowHeavy = Color.black.opacity(0.15)
}
