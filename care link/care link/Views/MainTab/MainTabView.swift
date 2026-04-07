import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab: CLTab = .home

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .home:
                    if appState.currentUserRole == .caregiver {
                        CaregiverDashboardView()
                    } else {
                        HomeView()
                    }
                case .chat:
                    ChatListView()
                case .map:
                    CaregiverMapView()
                case .alerts:
                    AlertsView()
                case .profile:
                    ProfileView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            CLTabBar(
                selectedTab: $selectedTab,
                badgeCount: appState.notificationService.unreadCount,
                chatBadgeCount: appState.chatService.conversations.filter {
                    appState.currentUserRole == .user ? $0.unreadCountUser > 0 : $0.unreadCountCaregiver > 0
                }.count,
                role: appState.currentUserRole
            )
        }
        .ignoresSafeArea(.keyboard)
    }
}

#Preview {
    MainTabView()
        .environment(AppState())
}
