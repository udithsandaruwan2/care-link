// File responsibility: Defines app delegate logic for the care link app.

import UIKit
import FirebaseCore
import FirebaseAuth
import FirebaseMessaging
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()

        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self

        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { _, _ in }
        application.registerForRemoteNotifications()

        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        return [.banner, .badge, .sound]
    }

    /// For deep links, the server must include `bookingId` and/or `conversationId` in the FCM **data** payload (see `AppState.applyPushRouting`).
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        let routingInfo = Self.pushRoutingUserInfo(from: userInfo)
        // Validate required values before continuing.
        guard !routingInfo.isEmpty else { return }
        await MainActor.run {
            // Use a safe fallback when data is missing.
            NotificationCenter.default.post(
                name: .careLinkPushNotificationTapped,
                object: nil,
                userInfo: routingInfo
            )
        }
    }

    private static func pushRoutingUserInfo(from userInfo: [AnyHashable: Any]) -> [String: String] {
        var routingInfo: [String: String] = [:]

        func stringValue(for key: String) -> String? {
            if let value = userInfo[key] as? String, !value.isEmpty {
                return value
            }
            if let data = userInfo["data"] as? [String: Any], let value = data[key] as? String, !value.isEmpty {
                return value
            }
            return nil
        }

        if let bookingId = stringValue(for: "bookingId") {
            routingInfo["bookingId"] = bookingId
        }
        if let conversationId = stringValue(for: "conversationId") {
            routingInfo["conversationId"] = conversationId
        }

        return routingInfo
    }

    // MARK: - MessagingDelegate

    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        print("FCM Token: \(token)")
    }
}
