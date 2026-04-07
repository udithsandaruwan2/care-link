import Foundation
import UserNotifications

@Observable
final class NotificationService {
    var isAuthorized = false
    var notifications: [CLNotification] = []

    func requestAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            isAuthorized = granted
        } catch {
            print("Notification auth error: \(error.localizedDescription)")
        }
    }

    func scheduleBookingReminder(booking: Booking) {
        let content = UNMutableNotificationContent()
        content.title = "Upcoming Appointment"
        content.body = "Your appointment with \(booking.caregiverName) is in 1 hour."
        content.sound = .default

        let reminderDate = booking.startTime.addingTimeInterval(-3600)
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: "booking_\(booking.id)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    func scheduleLocalNotification(title: String, body: String, timeInterval: TimeInterval = 1) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(timeInterval, 1), repeats: false)
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    func addNotification(_ notification: CLNotification) {
        notifications.insert(notification, at: 0)
    }

    func markAsRead(_ id: String) {
        if let index = notifications.firstIndex(where: { $0.id == id }) {
            notifications[index].isRead = true
        }
    }

    func markAllAsRead() {
        for i in notifications.indices {
            notifications[i].isRead = true
        }
    }

    var unreadCount: Int {
        notifications.filter { !$0.isRead }.count
    }
}
