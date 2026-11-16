import AdjustSdk
import AppTrackingTransparency
import Combine
import FirebaseCore
import FirebaseMessaging
import UIKit
import UserNotifications

final class ReferenceAppDelegate: NSObject, ObservableObject, UIApplicationDelegate, MessagingDelegate, UNUserNotificationCenterDelegate {
    @Published private(set) var notificationSelection = 0

    private let adjustToken = "o9rfryky794w"
    private let attribution = ReferenceAttributionObserver()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        if let project = FirebaseApp.app()?.options.googleAppID {
            LibrarySession.shared.configureMessaging(for: project)
        }
        let messaging = Messaging.messaging()
        messaging.delegate = self
        messaging.isAutoInitEnabled = true
        UNUserNotificationCenter.current().delegate = self

        if let config = ADJConfig(appToken: adjustToken, environment: ADJEnvironmentProduction) {
            config.delegate = attribution
            config.logLevel = .info
            Adjust.initSdk(config)
        }

        if let push = options?[.remoteNotification] as? [AnyHashable: Any] {
            LibrarySession.shared.selectNotification(identifier: Self.identifier(in: push))
        }
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken token: Data) {
        let messaging = Messaging.messaging()
        messaging.apnsToken = token
        messaging.token { token, _ in Self.updateToken(token) }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Reference Vault: APNs registration failed")
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken token: String?) {
        Self.updateToken(token)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completion: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if notification.request.trigger is UNPushNotificationTrigger {
            Messaging.messaging().appDidReceiveMessage(notification.request.content.userInfo)
        }
        completion([.banner, .list, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completion: @escaping () -> Void
    ) {
        defer { completion() }
        guard response.notification.request.trigger is UNPushNotificationTrigger else { return }
        let payload = response.notification.request.content.userInfo
        Messaging.messaging().appDidReceiveMessage(payload)
        let identifier = Self.identifier(in: payload)
        DispatchQueue.main.async {
            LibrarySession.shared.selectNotification(identifier: identifier)
            self.notificationSelection += 1
        }
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification payload: [AnyHashable: Any],
        fetchCompletionHandler completion: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        Messaging.messaging().appDidReceiveMessage(payload)
        completion(.newData)
    }

    private static func updateToken(_ rawToken: String?) {
        guard let token = rawToken?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty else { return }
        DispatchQueue.main.async { LibrarySession.shared.notificationToken = token }
    }

    private static func identifier(in payload: Any) -> String? {
        if let fields = payload as? [AnyHashable: Any] {
            for key in ["push_id", "gcm.notification.push_id"] {
                if let value = fields[key] {
                    let text = String(describing: value).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty { return text }
                }
            }
            for key in ["push_data", "data"] {
                if let body = fields[key], let id = identifier(in: body) { return id }
            }
        } else if let json = payload as? String,
                  let nested = try? JSONSerialization.jsonObject(with: Data(json.utf8)) {
            return identifier(in: nested)
        }
        return nil
    }
}

private final class ReferenceAttributionObserver: NSObject, AdjustDelegate {
    func adjustAttributionChanged(_ attribution: ADJAttribution?) {
        guard let attribution, ATTrackingManager.trackingAuthorizationStatus != .notDetermined else { return }
        let json = attribution.jsonResponse
            .flatMap { try? JSONSerialization.data(withJSONObject: $0) }
            .flatMap { String(data: $0, encoding: .utf8) }
        DispatchQueue.main.async { LibrarySession.shared.attributionJSON = json }
    }
}
