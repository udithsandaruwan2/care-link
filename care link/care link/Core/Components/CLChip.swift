// File responsibility: Defines c l chip logic for the care link app.

import SwiftUI

struct CLChip: View {
    let title: String
    var isSelected: Bool = false
    var action: (() -> Void)? = nil

    var body: some View {
        Group {
            if let action {
                Button {
                    action()
                } label: {
                    chipLabel
                }
                .buttonStyle(.plain)
                .accessibilityLabel(title)
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                .accessibilityValue(isSelected ? String(localized: "Selected") : String(localized: "Not selected"))
            } else {
                chipLabel
                    .accessibilityLabel(title)
                    .accessibilityValue(isSelected ? String(localized: "Selected") : String(localized: "Not selected"))
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }

    private var chipLabel: some View {
        Text(title)
            .font(CLTheme.calloutFont)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .foregroundStyle(isSelected ? .white : CLTheme.textPrimary)
            .background(isSelected ? CLTheme.primaryNavy : CLTheme.cardBackground)
            .clipShape(Capsule())
            .overlay {
                if !isSelected {
                    Capsule()
                        .stroke(CLTheme.divider, lineWidth: 1)
                }
            }
    }
}

struct CLBadge: View {
    let title: String
    var style: BadgeStyle = .filled

    enum BadgeStyle {
        case filled
        case outlined
    }

    var body: some View {
        Text(title)
            .font(CLTheme.captionFont)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .foregroundStyle(style == .filled ? .white : CLTheme.textPrimary)
            .background(style == .filled ? CLTheme.accentBlue : .clear)
            .clipShape(Capsule())
            .overlay {
                if style == .outlined {
                    Capsule()
                        .stroke(CLTheme.divider, lineWidth: 1)
                }
            }
            .accessibilityLabel(title)
            .accessibilityAddTraits(.isStaticText)
    }
}

#Preview {
    HStack {
        CLChip(title: "All", isSelected: true)
        CLChip(title: "Elderly")
        CLChip(title: "Child")
    }
}
