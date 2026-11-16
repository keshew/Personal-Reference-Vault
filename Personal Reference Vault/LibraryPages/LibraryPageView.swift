import SwiftUI
@preconcurrency import WebKit

struct LibraryPageView: View {
    @Binding var address: URL?
    @State private var waitingForFirstPage = true

    var body: some View {
        ZStack {
            LibraryPageHost(address: address) {
                waitingForFirstPage = false
            }
            if waitingForFirstPage {
                LibraryOpeningView()
                    .allowsHitTesting(false)
            }
        }
    }
}

private struct LibraryPageHost: UIViewRepresentable {
    let address: URL?
    let didLoad: () -> Void

    func makeUIView(context: Context) -> LibraryBrowser {
        LibraryBrowser()
    }

    func updateUIView(_ browser: LibraryBrowser, context: Context) {
        browser.didLoad = didLoad
        if let address { browser.load(address) }
    }
}

private final class LibraryBrowser: UIView, WKNavigationDelegate, WKUIDelegate {
    private static let appSchemes: Set<String> = ["tg", "telegram", "mailto", "tel", "sms", "whatsapp", "itms-apps"]
    private static let retryableFailures: Set<Int> = [
        NSURLErrorTimedOut, NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost,
        NSURLErrorNetworkConnectionLost, NSURLErrorDNSLookupFailed, NSURLErrorNotConnectedToInternet
    ]

    var didLoad: (() -> Void)?
    private var currentAddress: URL?
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
        attach(reader, safeArea: true)
    }

    required init?(coder: NSCoder) { nil }

    func load(_ address: URL) {
        guard currentAddress != address else { return }
        currentAddress = address
        retry?.cancel()
        retryCount = 0
        reader.load(URLRequest(url: address))
    }

    func webView(_ surface: WKWebView, didFinish navigation: WKNavigation!) {
        guard surface === reader else { return }
        retry?.cancel()
        didLoad?()
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
        attach(popup, safeArea: false)
        return popup
    }

    func webViewDidClose(_ surface: WKWebView) {
        if surface !== reader { surface.removeFromSuperview() }
    }

    func webViewWebContentProcessDidTerminate(_ surface: WKWebView) {
        guard recoveryCount < 2 else { return }
        recoveryCount += 1
        if let address = surface.url ?? (surface === reader ? currentAddress : nil) {
            surface.load(URLRequest(url: address))
        }
    }

    func webView(_ surface: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handle(error, from: surface)
    }

    func webView(_ surface: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        handle(error, from: surface)
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

    private func attach(_ surface: WKWebView, safeArea: Bool) {
        surface.translatesAutoresizingMaskIntoConstraints = false
        addSubview(surface)
        let guide = safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            surface.leadingAnchor.constraint(equalTo: safeArea ? guide.leadingAnchor : leadingAnchor),
            surface.trailingAnchor.constraint(equalTo: safeArea ? guide.trailingAnchor : trailingAnchor),
            surface.topAnchor.constraint(equalTo: safeArea ? guide.topAnchor : topAnchor),
            surface.bottomAnchor.constraint(equalTo: safeArea ? guide.bottomAnchor : bottomAnchor)
        ])
    }

    private func openExternalApp(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), Self.appSchemes.contains(scheme) else { return false }
        UIApplication.shared.open(url)
        return true
    }

    private func handle(_ error: Error, from surface: WKWebView) {
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
        let next = DispatchWorkItem { [weak surface] in
            surface?.load(URLRequest(url: address))
        }
        retry = next
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(retryCount), execute: next)
    }
}
