import SwiftUI

extension View {
    func clCardStyle() -> some View {
        self
            .background(CLTheme.cardBackground)
            .clipShape(CLTheme.continuousRect(cornerRadius: CLTheme.cornerRadiusLG))
            .shadow(color: CLTheme.shadowLight, radius: 10, x: 0, y: 3)
    }

    func clGlassStyle() -> some View {
        self
            .background(.ultraThinMaterial)
            .clipShape(CLTheme.continuousRect(cornerRadius: CLTheme.cornerRadiusLG))
    }

    func clSectionStyle() -> some View {
        self
            .padding(CLTheme.spacingMD)
            .background(CLTheme.cardBackground)
            .clipShape(CLTheme.continuousRect(cornerRadius: CLTheme.cornerRadiusLG))
            .shadow(color: CLTheme.shadowLight, radius: 6, x: 0, y: 2)
    }

    func shimmerEffect(_ isLoading: Bool) -> some View {
        self
            .redacted(reason: isLoading ? .placeholder : [])
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isLoading)
    }
}
