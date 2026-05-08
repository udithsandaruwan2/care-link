// File responsibility: Defines c l tab bar logic for the care link app.

import SwiftUI

enum CLTab: String, CaseIterable {
    case home = "HOME"
    case chat = "CHAT"
    case map = "MAP"
    case alerts = "NOTIFS"
    case profile = "PROFILE"

    var icon: String {
        // Handle each state transition explicitly.
        switch self {
        case .home: return "house"
        case .chat: return "bubble.left.and.bubble.right"
        case .map: return "map"
        case .alerts: return "bell"
        case .profile: return "person"
        }
    }

    var selectedIcon: String {
        // Handle each state transition explicitly.
        switch self {
        case .home: return "house.fill"
        case .chat: return "bubble.left.and.bubble.right.fill"
        case .map: return "map.fill"
        case .alerts: return "bell.fill"
        case .profile: return "person.fill"
        }
    }

    static func tabsForRole(_ role: CLUser.UserRole) -> [CLTab] {
        switch role {
        case .user:
            return [.home, .chat, .map, .alerts, .profile]
        case .caregiver:
            return [.home, .chat, .alerts, .profile]
        }
    }

    /// VoiceOver label (human-readable, not raw enum string).
    var voiceOverLabel: String {
        switch self {
        case .home: return String(localized: "Home")
        case .chat: return String(localized: "Chat")
        case .map: return String(localized: "Map")
        case .alerts: return String(localized: "Notifications")
        case .profile: return String(localized: "Profile")
        }
    }
}

struct CLTabBar: View {
    @Binding var selectedTab: CLTab
    var badgeCount: Int = 0
    var chatBadgeCount: Int = 0
    var role: CLUser.UserRole = .user
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var tabs: [CLTab] {
        CLTab.tabsForRole(role)
    }

    var body: some View {
        HStack {
            ForEach(tabs, id: \.self) { tab in
                Spacer()
                tabButton(tab)
                Spacer()
            }
        }
        .padding(.top, 14)
        .padding(.bottom, 10)
        .padding(.horizontal, CLTheme.spacingXS)
        .background(
            CLTheme.cardBackground
                .shadow(color: CLTheme.shadowMedium.opacity(0.85), radius: 16, x: 0, y: -6)
        )
        .clipShape(Capsule())
        .padding(.horizontal, CLTheme.spacingMD)
        .padding(.bottom, CLTheme.spacingSM)
    }

    private func tabButton(_ tab: CLTab) -> some View {
        Button {
            if reduceMotion {
                selectedTab = tab
            } else {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                    selectedTab = tab
                }
            }
        } label: {
            VStack(spacing: 5) {
                ZStack(alignment: .topTrailing) {
                    Group {
                        if reduceMotion {
                            Image(systemName: selectedTab == tab ? tab.selectedIcon : tab.icon)
                                .font(.system(size: 22))
                        } else {
                            Image(systemName: selectedTab == tab ? tab.selectedIcon : tab.icon)
                                .font(.system(size: 22))
                                .careLinkSymbolBounceIfAllowed(value: selectedTab == tab)
                        }
                    }

                    if tab == .alerts && badgeCount > 0 {
                        badgeDot
                            .accessibilityHidden(true)
                    }
                    if tab == .chat && chatBadgeCount > 0 {
                        badgeDot
                            .accessibilityHidden(true)
                    }
                }

                Text(tab.rawValue)
                    .font(.system(size: 9, weight: selectedTab == tab ? .bold : .medium))
                    .tracking(0.3)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(selectedTab == tab ? CLTheme.primaryNavy : CLTheme.textTertiary)
            .frame(minWidth: 52, minHeight: 44)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.voiceOverLabel)
        .accessibilityAddTraits(selectedTab == tab ? [.isButton, .isSelected] : .isButton)
        .careLinkAccessibilityHint(tabAccessibilityHint(tab: tab))
    }

    private func tabAccessibilityHint(tab: CLTab) -> String? {
        switch tab {
        case .alerts where badgeCount > 0:
            return String(localized: "\(badgeCount) unread notifications")
        case .chat where chatBadgeCount > 0:
            return String(localized: "\(chatBadgeCount) conversations with unread messages")
        default:
            return nil
        }
    }

    private var badgeDot: some View {
        Circle()
            .fill(CLTheme.errorRed)
            .frame(width: 8, height: 8)
            .offset(x: 4, y: -2)
    }
}

#Preview {
    CLTabBar(selectedTab: .constant(.home), badgeCount: 3, chatBadgeCount: 1)
}
