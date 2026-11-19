import AdjustSdk
import AdSupport
import AppTrackingTransparency
import OSLog
import SwiftUI
import UserNotifications

struct ReferenceLibraryView: View {
    @ObservedObject var appDelegate: ReferenceAppDelegate

    @State private var loadedPage: URL?
    @Environment(\.scenePhase) private var scenePhase
    @State private var page: URL?
    @State private var completedLaunch = false
    @State private var tab = TideTab.play
    @State private var games: [TideGame] = []
    @State private var isForeground = false
    @State private var needsSession = false
    @State private var permissionsPrepared = false
    @State private var attemptedToken: String?
    @State private var refreshTask: Task<Void, Never>?

    private let library = LibrarySession.shared
    private static let attributionTimeoutMilliseconds = 15_000
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "DiamondLuck", category: "Registration")

    var body: some View {
        let webContentIsReady = isPageVisible
        ZStack {
            if completedLaunch {
                TidePlayroom(tab: $tab, path: $games)
            }
            if !completedLaunch || (page != nil && games.isEmpty) {
                LibraryOpeningView()
            }
        }
        .task(id: waitsForRegistration) {
            guard waitsForRegistration else { return }
            do {
                try await Task.sleep(for: .seconds(15))
                if waitsForRegistration { finishLaunch() }
            } catch {}
        }
        .onAppear { updateScene(scenePhase) }
        .onChange(of: scenePhase) { updateScene($0) }
        .onChange(of: appDelegate.registrationRevision) { _ in refreshIfNeeded() }
        .onChange(of: appDelegate.notificationSelection) { _ in
            refreshIfNeeded()
        }
        .fullScreenCover(isPresented: Binding(
            get: { page != nil && games.isEmpty },
            set: { _ in }
        ), onDismiss: { loadedPage = nil }) {
            LibraryPageView(address: page, didLoad: { loadedPage = $0 })
                .accessibilityHidden(!webContentIsReady)
                .overlay {
                    if !webContentIsReady {
                        LibraryOpeningView(title: "Opening page…")
                    }
                }
                .interactiveDismissDisabled()
                .task(id: page) {
                    guard let requested = page, !isPageVisible else { return }
                    do {
                        try await Task.sleep(for: .seconds(25))
                        if page == requested, !isPageVisible {
                            page = nil
                        }
                    } catch {
                        return
                    }
                }
        }
    }

    private var isPageVisible: Bool {
        guard let requested = page else { return false }
        return loadedPage == requested
    }

    @MainActor
    private func updateScene(_ phase: ScenePhase) {
        if phase == .background {
            isForeground = false
            return
        }
        guard phase == .active, !isForeground else { return }
        isForeground = true
        needsSession = true
        refreshIfNeeded()
    }

    private var waitsForRegistration: Bool {
        isForeground && permissionsPrepared && !completedLaunch && library.notificationToken == nil
    }

    @MainActor
    private func refreshIfNeeded() {
        guard isForeground, refreshTask == nil else { return }
        refreshTask = Task { @MainActor in
            defer { refreshTask = nil }
            if !permissionsPrepared {
                await preparePermissions()
                permissionsPrepared = true
            }

            while isForeground, let token = library.notificationToken,
                  needsSession || library.hasPendingNotification || attemptedToken != token {
                let opensPage = needsSession || library.hasPendingNotification
                let notice = library.consumeNotification()
                needsSession = false
                attemptedToken = token
                await openPage(token: token, notice: notice, opensPage: opensPage)
            }
        }
    }

    @MainActor
    private func openPage(token: String, notice: LibrarySession.OpenedNotification?, opensPage: Bool) async {
        await requestTrackingIfActive()
        var adid = ""
        if ATTrackingManager.trackingAuthorizationStatus == .authorized {
            async let pendingADID = Adjust.adid(withTimeout: Self.attributionTimeoutMilliseconds)
            ReferenceAttributionObserver.record(await Adjust.attribution(withTimeout: Self.attributionTimeoutMilliseconds))
            adid = await pendingADID ?? ""
        }

        let trackingStatus = ATTrackingManager.trackingAuthorizationStatus
        let allowsTracking = trackingStatus == .authorized
        if !allowsTracking { library.attributionJSON = nil }

        let registration = LibraryPageService.Registration(
            notificationToken: token,
            attributionID: allowsTracking ? adid : "",
            advertisingID: allowsTracking ? ASIdentifierManager.shared().advertisingIdentifier.uuidString : "",
            model: UIDevice.current.model,
            notification: notice,
            attributionJSON: allowsTracking ? library.attributionJSON : nil
        )

        Self.logger.notice(
            "Sending registration. ATT: \(trackingStatus.rawValue), ADID: \(!registration.attributionID.isEmpty), attribution: \(registration.attributionJSON != nil)"
        )
        do {
            if let opened = try await LibraryPageService(library: library).open(registration),
               opensPage || page == nil {
                library.pageURL = opened
                page = opened
            }
        } catch {
            print("Diamond Luck: could not load the library page")
        }

        finishLaunch()
    }

    @MainActor
    private func finishLaunch() {
        if page == nil { page = library.pageURL }
        completedLaunch = true
    }

    @MainActor
    private func requestTrackingIfActive() async {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        for _ in 0..<10 {
            if UIApplication.shared.applicationState == .active { break }
            try? await Task.sleep(for: .milliseconds(300))
        }
        if UIApplication.shared.applicationState == .active {
            _ = await Adjust.requestAppTrackingAuthorization()
        }
    }

    @MainActor
    private func preparePermissions() async {
        await requestTrackingIfActive()

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        }
        if !UIApplication.shared.isRegisteredForRemoteNotifications {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
}

struct LibraryOpeningView: View {
    var title = "Connecting…"

    var body: some View {
        ZStack {
            Color(red: 0.97, green: 0.97, blue: 0.965).ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.large)
                    .tint(Color(red: 0.26, green: 0.29, blue: 0.32))
                    .accessibilityHidden(true)
                Text(title)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color(red: 0.12, green: 0.15, blue: 0.18))
                Text("Please wait a moment.")
                    .font(.subheadline)
                    .foregroundStyle(Color(red: 0.31, green: 0.34, blue: 0.37))
            }
            .multilineTextAlignment(.center)
            .padding(24)
            .accessibilityElement(children: .combine)
        }
    }
}
