import UIKit
import WebKit

// One page: its web view, what it shows, and how far it got.

@MainActor
final class Tab: NSObject, ObservableObject, Identifiable {
    let id: UUID
    let web: WKWebView
    weak var browser: Browser?

    @Published var title = ""
    @Published var url: URL?
    @Published var progress = 0.0
    @Published var loading = false
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var reading = false
    /// The band under the clock: the page's own colour, the one it asks
    /// for (theme-color), or else a bar it holds at its top, or its
    /// background (see Scripts.top); black under Dark Pages.
    @Published private(set) var shade: UIColor?
    private var pageTop: UIColor?

    private var watch: [NSKeyValueObservation] = []

    /// Search's own world for its page scripts: the page can't see them.
    static let world = WKContentWorld.world(name: "Search")

    var isBlank: Bool { url == nil }

    init(id: UUID = UUID(), browser: Browser, configuration: WKWebViewConfiguration? = nil) {
        self.id = id
        self.browser = browser
        let config = configuration ?? WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = .audio
        web = WKWebView(frame: .zero, configuration: config)
        super.init()
        web.allowsBackForwardNavigationGestures = true
        web.isInspectable = true
        // Without Safari's name, some sites hand a web view a page from 2012.
        let major = UIDevice.current.systemVersion.split(separator: ".").first ?? "18"
        web.customUserAgent = nil
        web.configuration.applicationNameForUserAgent = "Version/\(major).0 Mobile/15E148 Safari/604.1"
        web.navigationDelegate = self
        web.uiDelegate = self
        let controller = web.configuration.userContentController
        controller.removeScriptMessageHandler(forName: Forms.name, contentWorld: Tab.world)
        controller.add(FormsRelay(self), contentWorld: Tab.world, name: Forms.name)
        Shield.shared.protect(controller)
        arm()
        watch = [
            web.observe(\.title) { [weak self] web, _ in MainActor.assumeIsolated { self?.title = web.title ?? "" } },
            web.observe(\.url) { [weak self] web, _ in
                MainActor.assumeIsolated {
                    guard let self, let fresh = web.url, fresh.absoluteString != "about:blank" else { return }
                    self.url = fresh
                }
            },
            web.observe(\.estimatedProgress) { [weak self] web, _ in MainActor.assumeIsolated { self?.progress = web.estimatedProgress } },
            web.observe(\.isLoading) { [weak self] web, _ in MainActor.assumeIsolated { self?.loading = web.isLoading } },
            web.observe(\.canGoBack) { [weak self] web, _ in MainActor.assumeIsolated { self?.canGoBack = web.canGoBack } },
            web.observe(\.canGoForward) { [weak self] web, _ in MainActor.assumeIsolated { self?.canGoForward = web.canGoForward } },
            web.observe(\.themeColor) { [weak self] _, _ in MainActor.assumeIsolated { self?.reshade() } },
        ]
        reshade()
    }

    /// The scripts the next document gets: the sign-in helper always, and
    /// Dark Pages when it is on.
    func arm() {
        let controller = web.configuration.userContentController
        controller.removeAllUserScripts()
        controller.addUserScript(WKUserScript(source: Forms.script, injectionTime: .atDocumentEnd, forMainFrameOnly: true, in: Tab.world))
        controller.addUserScript(WKUserScript(source: Scripts.top, injectionTime: .atDocumentEnd, forMainFrameOnly: true, in: Tab.world))
        // What shows above and below the page — under the clock, past the
        // end — is painted in the page's own colour, white before Dark Pages
        // turns it over. Black while Dark Pages is on; the page's own otherwise.
        web.underPageBackgroundColor = browser?.darkPages == true ? .black : nil
        reshade()
        if browser?.darkPages == true {
            controller.addUserScript(WKUserScript(source: Scripts.dark, injectionTime: .atDocumentStart, forMainFrameOnly: true, in: Tab.world))
        }
    }

    /// A light page's theme-color would be a white band over the page Dark
    /// Pages has turned dark: then it is black, as the page is.
    private func reshade() {
        shade = browser?.darkPages == true ? .black : web.themeColor ?? pageTop
    }

    /// What the page script found at the top, as "rgb(r,g,b)".
    func sawTop(_ css: String) {
        let parts = css.split { !"0123456789.".contains($0) }.compactMap { Double($0) }
        guard parts.count >= 3 else { return }
        pageTop = UIColor(red: parts[0] / 255, green: parts[1] / 255, blue: parts[2] / 255, alpha: 1)
        reshade()
    }

    /// Dark Pages switched for the page already up, and for the next ones.
    func applyDark(_ on: Bool) {
        arm()
        guard !isBlank else { return }
        web.evaluateJavaScript(on ? Scripts.dark : Scripts.darkOff, in: nil, in: Tab.world) { _ in }
    }

    func go(to url: URL) {
        reading = false
        self.url = url
        web.load(URLRequest(url: url))
    }

    func back() { web.goBack() }
    func forward() { web.goForward() }

    func reload() {
        reading = false
        web.reload()
    }

    /// Reading mode, on or off. Off is the page again, reloaded.
    func toggleReader(textOnly: Bool, done: @escaping (Bool) -> Void) {
        if reading {
            reload()
            done(true)
            return
        }
        web.evaluateJavaScript(Scripts.reader, in: nil, in: .page) { [weak self] result in
            MainActor.assumeIsolated {
                guard let self, (try? result.get()) as? String == "read" else { return done(false) }
                self.reading = true
                if textOnly { self.web.evaluateJavaScript(Scripts.textOnly, in: nil, in: .page) { _ in } }
                self.web.evaluateJavaScript(Scripts.readerAfter, in: nil, in: Tab.world) { _ in }
                done(true)
            }
        }
    }

    func fill(_ login: Login) {
        web.evaluateJavaScript(Forms.fill(user: login.user, password: login.password), in: nil, in: Tab.world) { _ in }
        Vault.touch(login)
    }
}

// MARK: - WebKit

extension Tab: WKNavigationDelegate, WKUIDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
        guard let url = action.request.url, let scheme = url.scheme?.lowercased() else { return decisionHandler(.allow) }
        if ["http", "https", "about", "data", "blob", "file", "javascript"].contains(scheme) {
            return decisionHandler(.allow)
        }
        // Mail, phone, an app's own link: whoever owns it.
        UIApplication.shared.open(url)
        decisionHandler(.cancel)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        reading = false
        browser?.dismissLogins(for: self)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        browser?.saveSession()
        browser?.history.visit(url: webView.url, title: webView.title)
    }

    /// A link that wants a window of its own gets a tab of its own.
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard let browser else { return nil }
        let tab = browser.open(configuration: configuration)
        return tab.web
    }

    func webViewDidClose(_ webView: WKWebView) {
        browser?.close(self)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        webView.reload()
    }
}

/// The page's messages, held weakly: a controller keeps its handlers alive,
/// and a tab that kept itself alive that way would never go.
private final class FormsRelay: NSObject, WKScriptMessageHandler {
    weak var tab: Tab?

    init(_ tab: Tab) { self.tab = tab }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame, let body = message.body as? [String: Any], let kind = body["kind"] as? String else { return }
        MainActor.assumeIsolated {
            guard let tab, let browser = tab.browser else { return }
            switch kind {
            case "focus":
                browser.offerLogins(for: tab)
            case "submit":
                browser.offerToKeep(user: body["user"] as? String ?? "", password: body["password"] as? String ?? "", from: tab)
            case "top":
                tab.sawTop(body["color"] as? String ?? "")
            default:
                break
            }
        }
    }
}
