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
    private static let appSchemes: Set<String> = ["tg", "telegram", "mailto", "tel", "sms", "whatsapp", "itms-apps"]
    private static let retryableFailures: Set<Int> = [
        NSURLErrorTimedOut, NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost,
        NSURLErrorNetworkConnectionLost, NSURLErrorDNSLookupFailed, NSURLErrorNotConnectedToInternet
    ]

    var didLoad: ((URL) -> Void)?
    private var initialNavigation: WKNavigation?
    private var currentAddress: URL?
    private var popups: [WKWebView: UIStackView] = [:]
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

    func webView(_ surface: WKWebView, didFinish navigation: WKNavigation!) {
        guard surface === reader else { return }
        retry?.cancel()
        guard let navigation, navigation === initialNavigation, let currentAddress else { return }
        initialNavigation = nil
        didLoad?(currentAddress)
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
        let toolbar = UIView()
        toolbar.backgroundColor = .secondarySystemBackground
        let close = UIButton(type: .close)
        close.accessibilityLabel = "Close tab"
        close.addAction(UIAction { [weak self, weak popup] _ in
            if let popup { self?.closePopup(popup) }
        }, for: .touchUpInside)
        toolbar.addSubview(close)
        close.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            toolbar.heightAnchor.constraint(equalToConstant: 44),
            close.trailingAnchor.constraint(equalTo: toolbar.layoutMarginsGuide.trailingAnchor),
            close.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor)
        ])

        let tab = UIStackView(arrangedSubviews: [toolbar, popup])
        tab.axis = .vertical
        tab.backgroundColor = .systemBackground
        attach(tab)
        popups[popup] = tab
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
        guard let tab = popups.removeValue(forKey: surface) else { return }
        surface.stopLoading()
        tab.removeFromSuperview()
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
        handle(error, from: surface, navigation: navigation)
    }

    func webView(_ surface: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        handle(error, from: surface, navigation: navigation)
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
