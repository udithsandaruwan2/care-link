import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab: CLTab = .home
    /// Hides the floating tab bar during pushed flows so bottom toolbars (booking, chat composer, etc.) stay visible and tappable.
    @State private var homeStackHidesTabBar = false
    @State private var mapStackHidesTabBar = false
    @State private var chatStackHidesTabBar = false

    private var showsTabBar: Bool {
        switch selectedTab {
        case .home where appState.currentUserRole == .user:
            return !homeStackHidesTabBar
        case .map:
            return !mapStackHidesTabBar
        case .chat:
            return !chatStackHidesTabBar
        default:
            return true
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .home:
                    if appState.currentUserRole == .caregiver {
                        CaregiverDashboardView()
                    } else {
                        HomeView(suppressMainTabBar: $homeStackHidesTabBar)
                    }
                case .chat:
                    ChatListView(suppressMainTabBar: $chatStackHidesTabBar)
                case .map:
                    CaregiverMapView(suppressMainTabBar: $mapStackHidesTabBar)
                case .alerts:
                    AlertsView()
                case .profile:
                    ProfileView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if showsTabBar {
                CLTabBar(
                    selectedTab: $selectedTab,
                    badgeCount: appState.notificationService.unreadCount,
                    chatBadgeCount: appState.chatService.conversations.filter {
                        appState.currentUserRole == .user ? $0.unreadCountUser > 0 : $0.unreadCountCaregiver > 0
                    }.count,
                    role: appState.currentUserRole
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showsTabBar)
        .ignoresSafeArea(.keyboard)
    }
}

#Preview {
    MainTabView()
        .environment(AppState())
}
