import SwiftUI

struct CLCard<Content: View>: View {
    var padding: CGFloat = CLTheme.spacingMD
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CLTheme.cardBackground)
        .clipShape(CLTheme.continuousRect(cornerRadius: CLTheme.cornerRadiusLG))
        .shadow(color: CLTheme.shadowLight, radius: 10, x: 0, y: 3)
    }
}

struct CLInfoCard: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: CLTheme.spacingSM) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(CLTheme.accentBlue)
            Text(label.uppercased())
                .font(CLTheme.smallFont)
                .foregroundStyle(CLTheme.textTertiary)
                .tracking(1)
            Text(value)
                .font(CLTheme.headlineFont)
                .foregroundStyle(CLTheme.textPrimary)
        }
        .padding(CLTheme.spacingMD)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CLTheme.cardBackground)
        .clipShape(CLTheme.continuousRect(cornerRadius: CLTheme.cornerRadiusMD))
        .shadow(color: CLTheme.shadowLight, radius: 6, x: 0, y: 2)
    }
}

struct CLStatBadge: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: CLTheme.spacingXS) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(CLTheme.accentBlue)
            Text(value)
                .font(CLTheme.headlineFont)
                .foregroundStyle(CLTheme.textPrimary)
            Text(label.uppercased())
                .font(CLTheme.smallFont)
                .foregroundStyle(CLTheme.textTertiary)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    VStack(spacing: 16) {
        CLCard {
            Text("Card content here")
                .font(CLTheme.bodyFont)
        }
        HStack {
            CLInfoCard(icon: "calendar", label: "Date", value: "Oct 24, 2023")
            CLInfoCard(icon: "clock", label: "Time", value: "09:00 - 11:30 AM")
        }
    }
    .padding()
    .background(CLTheme.backgroundPrimary)
}
