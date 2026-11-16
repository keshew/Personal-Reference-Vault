import Foundation

final class LibrarySession {
    static let shared = LibrarySession()

    struct OpenedNotification: Codable {
        let identifier: String?
    }

    private struct Snapshot: Codable {
        var installationID: UUID? = nil
        var clientID: UUID? = nil
        var serviceURL: URL? = nil
        var pageURL: URL? = nil
        var messagingProject: String? = nil
        var notificationToken: String? = nil
        var attributionJSON: String? = nil
        var pendingNotification: OpenedNotification? = nil
    }

    let installationID: String
    let clientID: String

    private let defaults: UserDefaults
    private let storageKey = "referenceVault.librarySession"
    private var snapshot: Snapshot {
        didSet {
            if let encoded = try? JSONEncoder().encode(snapshot) {
                defaults.set(encoded, forKey: storageKey)
            }
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        var saved = defaults.data(forKey: storageKey)
            .flatMap { try? JSONDecoder().decode(Snapshot.self, from: $0) } ?? Snapshot()
        let installation = saved.installationID ?? UUID()
        let client = saved.clientID ?? UUID()
        let needsIdentifiers = saved.installationID == nil || saved.clientID == nil
        saved.installationID = installation
        saved.clientID = client
        installationID = installation.uuidString.lowercased()
        clientID = client.uuidString.lowercased()
        snapshot = saved
        if needsIdentifiers, let encoded = try? JSONEncoder().encode(saved) {
            defaults.set(encoded, forKey: storageKey)
        }
    }

    var serviceURL: URL? {
        get { snapshot.serviceURL }
        set { snapshot.serviceURL = newValue }
    }

    var pageURL: URL? {
        get { snapshot.pageURL }
        set { snapshot.pageURL = newValue }
    }

    var notificationToken: String? {
        get { snapshot.notificationToken }
        set { snapshot.notificationToken = newValue }
    }

    var attributionJSON: String? {
        get { snapshot.attributionJSON }
        set { snapshot.attributionJSON = newValue }
    }

    var hasPendingNotification: Bool { snapshot.pendingNotification != nil }

    func configureMessaging(for project: String) {
        guard snapshot.messagingProject != project else { return }
        var updated = snapshot
        updated.messagingProject = project
        updated.notificationToken = nil
        snapshot = updated
    }

    func selectNotification(identifier: String?) {
        snapshot.pendingNotification = OpenedNotification(identifier: identifier)
    }

    func consumeNotification() -> OpenedNotification? {
        guard let selected = snapshot.pendingNotification else { return nil }
        snapshot.pendingNotification = nil
        return selected
    }
}
