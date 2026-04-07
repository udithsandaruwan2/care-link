import SwiftUI

extension View {
    func clCardStyle() -> some View {
        self
            .background(CLTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: CLTheme.cornerRadiusLG))
            .shadow(color: CLTheme.shadowLight, radius: 8, x: 0, y: 2)
    }

    func clGlassStyle() -> some View {
        self
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: CLTheme.cornerRadiusLG))
    }

    func clSectionStyle() -> some View {
        self
            .padding(CLTheme.spacingMD)
            .background(CLTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: CLTheme.cornerRadiusLG))
            .shadow(color: CLTheme.shadowLight, radius: 4, x: 0, y: 1)
    }

    func shimmerEffect(_ isLoading: Bool) -> some View {
        self
            .redacted(reason: isLoading ? .placeholder : [])
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isLoading)
    }
}
