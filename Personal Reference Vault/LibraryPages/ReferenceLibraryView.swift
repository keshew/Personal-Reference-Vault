import AdjustSdk
import AdSupport
import AppTrackingTransparency
import SwiftUI
import UserNotifications

struct ReferenceLibraryView: View {
    @ObservedObject var appDelegate: ReferenceAppDelegate

    @Environment(\.scenePhase) private var scenePhase
    @State private var page: URL?
    @State private var tab = TideTab.play
    @State private var games: [TideGame] = []
    @State private var staysInPlayroom = false
    @State private var isForeground = false
    @State private var needsSession = false
    @State private var permissionsPrepared = false
    @State private var attemptedToken: String?
    @State private var refreshTask: Task<Void, Never>?

    private let library = LibrarySession.shared

    var body: some View {
        TidePlayroom(tab: $tab, path: $games)
        .onAppear { updateScene(scenePhase) }
        .onChange(of: scenePhase) { updateScene($0) }
        .onChange(of: appDelegate.registrationRevision) { _ in refreshIfNeeded() }
        .onChange(of: appDelegate.notificationSelection) { _ in
            staysInPlayroom = false
            refreshIfNeeded()
        }
        .fullScreenCover(isPresented: Binding(
            get: { page != nil && games.isEmpty && !staysInPlayroom },
            set: { _ in }
        )) {
            LibraryPageView(address: $page)
                .ignoresSafeArea()
                .safeAreaInset(edge: .top, spacing: 0) {
                    Button {
                        staysInPlayroom = true
                        tab = .play
                    } label: {
                        Label("Back to play", systemImage: "arrow.left")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .padding(.horizontal, 20)
                    }
                    .buttonStyle(.plain)
                    .background(.regularMaterial)
                }
                .interactiveDismissDisabled()
        }
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
        if !staysInPlayroom, !library.hasPendingNotification, page == nil {
            page = library.pageURL
        }
        refreshIfNeeded()
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
        let allowsTracking = ATTrackingManager.trackingAuthorizationStatus == .authorized
        var attributionID = ""
        var advertisingID = ""
        if allowsTracking {
            let current = await Adjust.attribution(withTimeout: 1_000)
            ReferenceAttributionObserver.record(current)
            attributionID = await Adjust.adid(withTimeout: 1_000) ?? ""
            advertisingID = ASIdentifierManager.shared().advertisingIdentifier.uuidString
        } else {
            library.attributionJSON = nil
        }

        let registration = LibraryPageService.Registration(
            notificationToken: token,
            attributionID: attributionID,
            advertisingID: advertisingID,
            model: UIDevice.current.model,
            notification: notice,
            attributionJSON: allowsTracking ? library.attributionJSON : nil
        )

        do {
            if let opened = try await LibraryPageService(library: library).open(registration),
               opensPage || page == nil {
                library.pageURL = opened
                if !staysInPlayroom { page = opened }
            }
        } catch {
            print("Diamond Luck: could not load the library page")
        }

        if page == nil, !staysInPlayroom { page = library.pageURL }
    }

    @MainActor
    private func preparePermissions() async {
        if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
            for _ in 0..<10 {
                if UIApplication.shared.applicationState == .active { break }
                try? await Task.sleep(for: .milliseconds(300))
            }
            if UIApplication.shared.applicationState == .active {
                _ = await Adjust.requestAppTrackingAuthorization()
            }
        }

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
    var body: some View {
        ZStack {
            VaultStyle.background.ignoresSafeArea()
            VStack(spacing: 18) {
                BrandMark(size: 54)
                Text("Diamond Luck")
                    .font(.system(.largeTitle, design: .serif))
                    .foregroundStyle(VaultStyle.ink)
                ProgressView()
                    .tint(VaultStyle.accent)
            }
        }
    }
}
