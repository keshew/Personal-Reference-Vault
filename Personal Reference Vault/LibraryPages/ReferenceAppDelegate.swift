import AdjustSdk
import AppTrackingTransparency
import Combine
import FirebaseCore
import FirebaseMessaging
import UIKit
import UserNotifications

final class ReferenceAppDelegate: NSObject, ObservableObject, UIApplicationDelegate, MessagingDelegate, UNUserNotificationCenterDelegate {
    @Published private(set) var notificationSelection = 0
    @Published private(set) var registrationRevision = 0

    private let adjustToken = "o9rfryky794w"
    private let attribution = ReferenceAttributionObserver()
    private var tokenRequest: Task<Void, Never>?

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
        application.registerForRemoteNotifications()

        if let config = ADJConfig(appToken: adjustToken, environment: ADJEnvironmentProduction) {
            config.delegate = attribution
            config.logLevel = .info
            config.attConsentWaitingInterval = 30
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
        tokenRequest?.cancel()
        tokenRequest = Task { @MainActor [weak self] in
            for delay in [0, 2, 5] {
                do {
                    if delay > 0 { try await Task.sleep(for: .seconds(delay)) }
                    try Task.checkCancellation()
                    let registration = try await messaging.token()
                    try Task.checkCancellation()
                    self?.retainToken(registration)
                    return
                } catch {
                    if Task.isCancelled { return }
                }
            }
            print("Diamond Luck: could not retrieve FCM token after APNs registration")
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Diamond Luck: APNs registration failed")
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken token: String?) {
        guard messaging.apnsToken != nil else { return }
        DispatchQueue.main.async { [weak self] in self?.retainToken(token) }
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

    @MainActor
    private func retainToken(_ rawToken: String?) {
        guard let token = rawToken?.trimmingCharacters(in: .whitespacesAndNewlines),
              !token.isEmpty, token != "null", token != LibrarySession.shared.notificationToken else { return }
        LibrarySession.shared.notificationToken = token
        registrationRevision += 1
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

final class ReferenceAttributionObserver: NSObject, AdjustDelegate {
    func adjustAttributionChanged(_ attribution: ADJAttribution?) {
        DispatchQueue.main.async { Self.record(attribution) }
    }

    static func record(_ attribution: ADJAttribution?) {
        guard ATTrackingManager.trackingAuthorizationStatus == .authorized,
              let values = attribution?.jsonResponse,
              let json = try? JSONSerialization.data(withJSONObject: values) else { return }
        LibrarySession.shared.attributionJSON = String(data: json, encoding: .utf8)
    }
}
