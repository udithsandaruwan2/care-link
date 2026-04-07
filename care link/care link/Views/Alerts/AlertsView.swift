import SwiftUI

struct AlertsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Text("Notifications")
                        .font(CLTheme.titleFont)
                        .foregroundStyle(CLTheme.textPrimary)
                    Spacer()
                    if appState.notificationService.unreadCount > 0 {
                        Button("Mark all read") {
                            appState.notificationService.markAllAsRead()
                        }
                        .font(CLTheme.calloutFont)
                        .foregroundStyle(CLTheme.accentBlue)
                    }
                }
                .padding(.horizontal, CLTheme.spacingMD)
                .padding(.vertical, CLTheme.spacingSM)

                if appState.notificationService.notifications.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: CLTheme.spacingSM) {
                            ForEach(appState.notificationService.notifications) { notification in
                                notificationRow(notification)
                            }
                        }
                        .padding(.horizontal, CLTheme.spacingMD)
                        .padding(.bottom, 100)
                    }
                }
            }
            .background(CLTheme.backgroundPrimary)
        }
    }

    private func notificationRow(_ notification: CLNotification) -> some View {
        Button {
            appState.notificationService.markAsRead(notification.id)
        } label: {
            HStack(alignment: .top, spacing: CLTheme.spacingMD) {
                ZStack {
                    Circle()
                        .fill(Color(hex: notification.type.colorHex).opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: notification.type.iconName)
                        .font(.system(size: 18))
                        .foregroundStyle(Color(hex: notification.type.colorHex))
                }

                VStack(alignment: .leading, spacing: CLTheme.spacingXS) {
                    HStack {
                        Text(notification.title)
                            .font(notification.isRead ? CLTheme.bodyFont : CLTheme.headlineFont)
                            .foregroundStyle(CLTheme.textPrimary)
                        Spacer()
                        if !notification.isRead {
                            Circle()
                                .fill(CLTheme.accentBlue)
                                .frame(width: 8, height: 8)
                        }
                    }

                    Text(notification.message)
                        .font(CLTheme.captionFont)
                        .foregroundStyle(CLTheme.textSecondary)
                        .lineLimit(2)

                    Text(notification.createdAt, style: .relative)
                        .font(CLTheme.captionFont)
                        .foregroundStyle(CLTheme.textTertiary)
                }
            }
            .padding(CLTheme.spacingMD)
            .background(notification.isRead ? CLTheme.cardBackground : CLTheme.lightBlue.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: CLTheme.cornerRadiusMD))
        }
    }

    private var emptyState: some View {
        VStack(spacing: CLTheme.spacingMD) {
            Spacer()
            Image(systemName: "bell.slash")
                .font(.system(size: 48))
                .foregroundStyle(CLTheme.textTertiary)
            Text("No notifications")
                .font(CLTheme.headlineFont)
                .foregroundStyle(CLTheme.textSecondary)
            Text("You're all caught up! Notifications about bookings and updates will appear here.")
                .font(CLTheme.bodyFont)
                .foregroundStyle(CLTheme.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, CLTheme.spacingXL)
            Spacer()
        }
    }
}

#Preview {
    AlertsView()
        .environment(AppState())
}
