import AppKit
import WebKit

@MainActor
final class WebChecks: NSObject, WKScriptMessageHandler {
    let web: WKWebView
    let window: NSWindow
    var focuses = 0
    var checks = 0
    override init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        web = WKWebView(frame: NSRect(x: 0, y: 0, width: 400, height: 600), configuration: config)
        window = NSWindow(contentRect: web.frame, styleMask: .borderless, backing: .buffered, defer: false)
        super.init()
        window.isReleasedWhenClosed = false
        window.contentView = web
        window.setFrameOrigin(NSPoint(x: -10000, y: -10000))
        window.orderFrontRegardless()
        web.configuration.userContentController.add(self, name: Forms.name)
        web.configuration.userContentController.addUserScript(WKUserScript(source: Forms.script, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
    }
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        if (message.body as? [String: Any])?["kind"] as? String == "focus" { focuses += 1 }
    }
    func evaluate(_ script: String) async throws -> Any? {
        try await withCheckedThrowingContinuation { done in
            web.evaluateJavaScript(script) { result, error in
                if let error { done.resume(throwing: error) } else { done.resume(returning: result) }
            }
        }
    }
    func expect(_ condition: Bool, _ name: String) throws {
        guard condition else { throw NSError(domain: "WebChecks", code: 1, userInfo: [NSLocalizedDescriptionKey: name]) }
        checks += 1
        print("PASS: \(name)")
    }
    func focus(_ id: String, offered: Bool) async throws {
        let before = focuses
        _ = try await evaluate("document.activeElement.blur(); document.getElementById('\(id)').focus(); true")
        try await Task.sleep(nanoseconds: 150_000_000)
        try expect((focuses > before) == offered, "\(id): credential suggestions \(offered ? "offered" : "excluded")")
    }
    func run() async throws {
        web.loadHTMLString("""
        <!doctype html><form>
        <input id="user" name="username" autocomplete="username">
        <input id="search" name="username" aria-label="Search repositories">
        <input id="title" name="title" placeholder="Title">
        <input id="otp" name="username" autocomplete="one-time-code">
        <input id="password" type="password"></form>
        <form role="search"><input id="role" name="username"></form>
        <input id="placeholder" name="username" placeholder="Search repositories">
        <form><input id="generic" name="field"><input id="label" name="title"><input id="secret" type="password"></form>
        """, baseURL: nil)
        var ready = false
        for _ in 0..<150 {
            if (try? await evaluate("!!window.__searchForms")) as? Bool == true { ready = true; break }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        try expect(ready, "production form script loaded in WebKit")
        try await focus("user", offered: true)
        try await focus("password", offered: true)
        for id in ["search", "title", "otp", "role", "placeholder"] { try await focus(id, offered: false) }
        try await focus("secret", offered: true)
        _ = try await evaluate(Forms.fill(user: "fixture-user", password: "fixture-password"))
        let result = try await evaluate("[document.getElementById('generic').value, document.getElementById('label').value, document.getElementById('secret').value]") as? [String]
        try expect(result == ["fixture-user", "", "fixture-password"], "fill preserves title field and chooses the login fields")
        let regex = try NSRegularExpression(pattern: Shield.networkFilter(for: "segment.com"))
        func matches(_ text: String) -> Bool { regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil }
        try expect(["https://segment.com/track", "https://cdn.segment.com:8443/track"].allSatisfy(matches), "blocker matches listed domains and subdomains")
        try expect(["https://segment.company/a", "https://segment.com.example/a", "https://notsegment.com/a"].allSatisfy { !matches($0) }, "blocker allows lookalike domains")
        let rules: [[String: Any]] = [["trigger": ["url-filter": Shield.networkFilter(for: "segment.com")], "action": ["type": "block"]]]
        let json = String(data: try JSONSerialization.data(withJSONObject: rules), encoding: .utf8)!
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("brou-rules-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = WKContentRuleListStore(url: folder)!
        let compiled = try await store.compileContentRuleList(forIdentifier: "brou-upstream-regression", encodedContentRuleList: json)
        try expect(compiled != nil, "domain boundary compiles in WebKit")
        try await store.removeContentRuleList(forIdentifier: "brou-upstream-regression")
        window.close()
        print("\(checks) passed, 0 failed")
    }
}
@MainActor
final class WebRunner: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            do { try await WebChecks().run(); exit(0) }
            catch { fputs("FAIL: \(error)\n", stderr); exit(1) }
        }
    }
}
@main struct RunWebChecks {
    @MainActor static func main() {
        let app = NSApplication.shared
        let runner = WebRunner()
        app.delegate = runner
        app.run()
    }
}
