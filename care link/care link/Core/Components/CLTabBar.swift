import SwiftUI

enum CLTab: String, CaseIterable {
    case home = "HOME"
    case chat = "CHAT"
    case map = "MAP"
    case alerts = "ALERTS"
    case profile = "PROFILE"

    var icon: String {
        switch self {
        case .home: return "house"
        case .chat: return "bubble.left.and.bubble.right"
        case .map: return "map"
        case .alerts: return "bell"
        case .profile: return "person"
        }
    }

    var selectedIcon: String {
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
}

struct CLTabBar: View {
    @Binding var selectedTab: CLTab
    var badgeCount: Int = 0
    var chatBadgeCount: Int = 0
    var role: CLUser.UserRole = .user

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
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(
            CLTheme.cardBackground
                .shadow(color: CLTheme.shadowMedium, radius: 12, x: 0, y: -4)
        )
        .clipShape(RoundedRectangle(cornerRadius: CLTheme.cornerRadiusXL))
        .padding(.horizontal, CLTheme.spacingMD)
        .padding(.bottom, CLTheme.spacingSM)
    }

    private func tabButton(_ tab: CLTab) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: selectedTab == tab ? tab.selectedIcon : tab.icon)
                        .font(.system(size: 22))
                        .symbolEffect(.bounce, value: selectedTab == tab)

                    if tab == .alerts && badgeCount > 0 {
                        badgeDot
                    }
                    if tab == .chat && chatBadgeCount > 0 {
                        badgeDot
                    }
                }

                Text(tab.rawValue)
                    .font(.system(size: 10, weight: selectedTab == tab ? .bold : .medium))
            }
            .foregroundStyle(selectedTab == tab ? CLTheme.primaryNavy : CLTheme.textTertiary)
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
