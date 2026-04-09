import SwiftUI

struct CLChip: View {
    let title: String
    var isSelected: Bool = false
    var action: (() -> Void)? = nil

    var body: some View {
        Button {
            action?()
        } label: {
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
        .buttonStyle(.plain)
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
    }
}

#Preview {
    HStack {
        CLChip(title: "All", isSelected: true)
        CLChip(title: "Elderly")
        CLChip(title: "Child")
    }
}
