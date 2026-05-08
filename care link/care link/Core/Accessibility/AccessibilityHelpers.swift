// File responsibility: Defines accessibility helpers logic for the care link app.

import SwiftUI

// MARK: - Environment

private struct ReduceMotionKey: EnvironmentKey {
    // Use a safe fallback when data is missing.
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    /// Mirrors UIAccessibility.isReduceMotionEnabled for SwiftUI previews and tests.
    var careLinkReduceMotion: Bool {
        get { self[ReduceMotionKey.self] }
        set { self[ReduceMotionKey.self] = newValue }
    }
}

extension View {
    /// Ensures a minimum hit target (44pt) per HIG accessibility guidance.
    func careLinkMinimumTapTarget(_ size: CGFloat = 44) -> some View {
        frame(minWidth: size, minHeight: size)
            .contentShape(Rectangle())
    }

    @ViewBuilder
    func careLinkAccessibilityHint(_ text: String?) -> some View {
        if let text, !text.isEmpty {
            accessibilityHint(text)
        } else {
            self
        }
    }

    @ViewBuilder
    func careLinkAccessibilityValue(_ value: String?) -> some View {
        if let value, !value.isEmpty {
            accessibilityValue(value)
        } else {
            self
        }
    }

    @ViewBuilder
    func careLinkSymbolBounceIfAllowed<Value: Equatable>(value: Value) -> some View {
        modifier(CareLinkSymbolBounceModifier(value: value))
    }
}

private struct CareLinkSymbolBounceModifier<Value: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let value: Value

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.symbolEffect(.bounce, value: value)
        }
    }
}
