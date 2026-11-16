import AdjustSdk
import AdSupport
import AppTrackingTransparency
import SwiftUI
import UserNotifications

struct ReferenceLibraryView: View {
    @ObservedObject var appDelegate: ReferenceAppDelegate

    @State private var page: URL?
    @State private var isStarting = true
    @State private var started = false
    @State private var loading = false

    private let library = LibrarySession.shared

    var body: some View {
        Group {
            if isStarting {
                LibraryOpeningView()
            } else {
                ContentView()
            }
        }
        .task {
            guard !started else { return }
            started = true
            if !library.hasPendingNotification {
                page = library.pageURL
            }
            await refresh()
        }
        .onChange(of: appDelegate.notificationSelection) { _ in
            guard started else { return }
            Task { await refresh() }
        }
        .fullScreenCover(isPresented: Binding(get: { page != nil }, set: { _ in })) {
            LibraryPageView(address: $page)
                .ignoresSafeArea()
                .interactiveDismissDisabled()
        }
    }

    @MainActor
    private func refresh() async {
        guard !loading else { return }
        loading = true
        defer { loading = false }

        repeat {
            await prepareRegistration()
            guard !Task.isCancelled else { return }
            let notification = library.consumeNotification()
            let rawAttribution = library.attributionJSON
            let token = library.notificationToken
            let attribution = await Adjust.adid(withTimeout: 1_000) ?? ""
            let advertisingID = ATTrackingManager.trackingAuthorizationStatus == .authorized
                ? ASIdentifierManager.shared().advertisingIdentifier.uuidString : ""
            let registration = LibraryPageService.Registration(
                notificationToken: token,
                attributionID: attribution,
                advertisingID: advertisingID,
                model: UIDevice.current.model,
                notification: notification,
                attributionJSON: rawAttribution
            )

            do {
                if let opened = try await LibraryPageService(library: library).open(registration) {
                    library.pageURL = opened
                    page = opened
                }
            } catch {
                if Task.isCancelled { return }
                print("Reference Vault: could not load the library page")
            }

            if page == nil { page = library.pageURL }
            if page == nil { isStarting = false }
        } while library.hasPendingNotification
    }

    @MainActor
    private func prepareRegistration() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        }
        UIApplication.shared.registerForRemoteNotifications()

        try? await Task.sleep(for: .milliseconds(500))
        if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
            for _ in 0..<10 where UIApplication.shared.applicationState != .active {
                if Task.isCancelled { return }
                try? await Task.sleep(for: .milliseconds(300))
            }
            if !Task.isCancelled, UIApplication.shared.applicationState == .active {
                _ = await Adjust.requestAppTrackingAuthorization()
            }
        }

        for _ in 0..<15 {
            if Task.isCancelled || (library.attributionJSON != nil && library.notificationToken != nil) { return }
            try? await Task.sleep(for: .seconds(1))
        }
    }
}

struct LibraryOpeningView: View {
    var body: some View {
        ZStack {
            VaultStyle.background.ignoresSafeArea()
            VStack(spacing: 18) {
                BrandMark(size: 54)
                Text("Reference Vault")
                    .font(.system(.largeTitle, design: .serif))
                    .foregroundStyle(VaultStyle.ink)
                ProgressView()
                    .tint(VaultStyle.accent)
            }
        }
    }
}
