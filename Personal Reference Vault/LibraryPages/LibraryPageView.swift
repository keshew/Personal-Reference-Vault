import OSLog
import SwiftUI
@preconcurrency import WebKit

struct LibraryPageView: UIViewRepresentable {
    let address: URL?
    let didLoad: (URL) -> Void

    func makeUIView(context: Context) -> LibraryBrowser {
        LibraryBrowser()
    }

    func updateUIView(_ browser: LibraryBrowser, context: Context) {
        browser.didLoad = didLoad
        if let address { browser.load(address) }
    }
}

final class LibraryBrowser: UIView, WKNavigationDelegate, WKUIDelegate {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "LibraryPages", category: "WebNavigation")
    private static let appSchemes: Set<String> = ["tg", "telegram", "mailto", "tel", "sms", "whatsapp", "itms-apps"]
    private static let retryableFailures: Set<Int> = [
        NSURLErrorTimedOut, NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost,
        NSURLErrorNetworkConnectionLost, NSURLErrorDNSLookupFailed, NSURLErrorNotConnectedToInternet
    ]

    var didLoad: ((URL) -> Void)?
    private var initialNavigation: WKNavigation?
    private var currentAddress: URL?
    private var popups: Set<WKWebView> = []
    private var retryCount = 0
    private var recoveryCount = 0
    private var retry: DispatchWorkItem?
    private lazy var reader: WKWebView = {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        return makePage(configuration)
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .white
        attach(reader)
    }

    required init?(coder: NSCoder) { nil }

    func load(_ address: URL) {
        guard currentAddress != address else { return }
        currentAddress = address
        retry?.cancel()
        retryCount = 0
        initialNavigation = reader.load(URLRequest(url: address))
    }

    func webView(_ surface: WKWebView, didCommit navigation: WKNavigation!) {
        if popups.contains(surface) {
            // The initial empty document must not cover the opener for an HTTP request.
            if let url = surface.url, url.absoluteString != "about:blank" {
                surface.isHidden = false
            }
            logger.info("New window committed a document")
        }
        guard surface === reader, let navigation, navigation === initialNavigation, let currentAddress else { return }
        retry?.cancel()
        initialNavigation = nil
        didLoad?(currentAddress)
    }

    func webView(
        _ surface: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
    ) {
        if popups.contains(surface), navigationResponse.isForMainFrame,
           let response = navigationResponse.response as? HTTPURLResponse {
            logger.info("New window received HTTP \(response.statusCode, privacy: .public)")
        }
        decisionHandler(.allow)
    }

    func webView(_ surface: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let opensElsewhere = action.request.url.map(openExternalApp) ?? false
        decisionHandler(opensElsewhere ? .cancel : .allow)
    }

    func webView(_ surface: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = action.request.url, openExternalApp(url) { return nil }
        let popup = makePage(configuration)
        popup.customUserAgent = surface.customUserAgent
        let scheme = action.request.url?.scheme?.lowercased() ?? "none"
        // Empty windows can be filled directly by the opener, without an HTTP response.
        popup.isHidden = scheme == "http" || scheme == "https"
        attach(popup)
        popups.insert(popup)
        logger.info("Created new window for URL scheme \(scheme, privacy: .public)")
        return popup
    }

    func webViewDidClose(_ surface: WKWebView) {
        closePopup(surface)
    }

    func webView(_ surface: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType,
                 decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(.prompt)
    }

    private func closePopup(_ surface: WKWebView) {
        guard popups.remove(surface) != nil else { return }
        surface.stopLoading()
        surface.removeFromSuperview()
    }

    func webViewWebContentProcessDidTerminate(_ surface: WKWebView) {
        guard recoveryCount < 2 else { return }
        recoveryCount += 1
        if let address = surface.url ?? (surface === reader ? currentAddress : nil) {
            let recovery = surface.load(URLRequest(url: address))
            if surface === reader, initialNavigation != nil { initialNavigation = recovery }
        }
    }

    func webView(_ surface: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handlePopupFailure(error, in: surface)
        handle(error, from: surface, navigation: navigation)
    }

    func webView(_ surface: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        handlePopupFailure(error, in: surface)
        handle(error, from: surface, navigation: navigation)
    }

    private func handlePopupFailure(_ error: Error, in surface: WKWebView) {
        guard popups.contains(surface) else { return }
        let failure = error as NSError
        guard failure.domain != NSURLErrorDomain || failure.code != NSURLErrorCancelled else { return }
        logger.error("New window navigation failed: \(failure.domain, privacy: .public) \(failure.code, privacy: .public)")
        if surface.isHidden {
            closePopup(surface)
        }
    }

    private func makePage(_ configuration: WKWebViewConfiguration) -> WKWebView {
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        let surface = WKWebView(frame: .zero, configuration: configuration)
        surface.customUserAgent = LibraryPageService.browserAgent
        surface.navigationDelegate = self
        surface.uiDelegate = self
        surface.allowsBackForwardNavigationGestures = true
        return surface
    }

    private func attach(_ surface: UIView) {
        surface.translatesAutoresizingMaskIntoConstraints = false
        addSubview(surface)
        let guide = safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            surface.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
            surface.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
            surface.topAnchor.constraint(equalTo: guide.topAnchor),
            surface.bottomAnchor.constraint(equalTo: guide.bottomAnchor)
        ])
    }

    private func openExternalApp(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), Self.appSchemes.contains(scheme) else { return false }
        UIApplication.shared.open(url)
        return true
    }

    private func handle(_ error: Error, from surface: WKWebView, navigation: WKNavigation?) {
        let failure = error as NSError
        guard failure.domain == NSURLErrorDomain else { return }
        let failed = (failure.userInfo[NSURLErrorFailingURLErrorKey] as? URL)
            ?? (failure.userInfo[NSURLErrorFailingURLStringErrorKey] as? String).flatMap(URL.init(string:))

        if failure.code == NSURLErrorUnsupportedURL {
            if let url = failed ?? surface.url,
               let scheme = url.scheme?.lowercased(), scheme != "https", scheme != "http" {
                UIApplication.shared.open(url)
            }
            return
        }

        guard surface === reader, Self.retryableFailures.contains(failure.code), retryCount < 2,
              let address = failed ?? surface.url ?? currentAddress else { return }
        retryCount += 1
        retry?.cancel()
        let isInitial = navigation != nil && navigation === initialNavigation
        let next = DispatchWorkItem { [weak self, weak surface] in
            guard let self, let surface else { return }
            let retry = surface.load(URLRequest(url: address))
            if isInitial { self.initialNavigation = retry }
        }
        retry = next
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(retryCount), execute: next)
    }
}
