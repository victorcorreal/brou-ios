import AppKit
import WebKit

/// Executes the shipped page-colour script against rendered local documents.
/// No browser profile, network request, iCloud account or credentials are used.
@MainActor
final class TopColorHarness: NSObject, WKScriptMessageHandler {
    let web: WKWebView
    let window: NSWindow
    var colours: [String] = []

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        web = WKWebView(frame: NSRect(x: 0, y: 0, width: 400, height: 600), configuration: configuration)
        window = NSWindow(contentRect: web.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        super.init()
        web.configuration.userContentController.add(self, name: "searchForms")
        // An off-screen WebKit view suspends animation frames. Keep the real
        // DOM/CSS/layout but drive the queued samples with timers in this test.
        web.configuration.userContentController.addUserScript(WKUserScript(
            source: "window.requestAnimationFrame = callback => setTimeout(() => callback(performance.now()), 0);",
            injectionTime: .atDocumentStart, forMainFrameOnly: true))
        web.configuration.userContentController.addUserScript(WKUserScript(source: Scripts.top, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        window.isReleasedWhenClosed = false
        window.contentView = web
        window.setFrameOrigin(NSPoint(x: -10000, y: -10000))
        window.orderFrontRegardless()
    }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        if let body = message.body as? [String: String], body["kind"] == "top", let c = body["color"] { colours.append(c) }
    }

    func evaluate(_ script: String) async throws {
        try await withCheckedThrowingContinuation { (done: CheckedContinuation<Void, Error>) in
            web.evaluateJavaScript(script) { _, error in
                if let error { done.resume(throwing: error) } else { done.resume() }
            }
        }
    }

    func expect(_ colour: String, _ name: String) async throws {
        for _ in 0..<150 {
            if colours.last == colour { print("PASS: \(name)"); return }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        let diagnostic: String = await withCheckedContinuation { done in
            web.evaluateJavaScript("JSON.stringify({ready:document.readyState, script:window.__searchTop, width:innerWidth, height:innerHeight})") { result, error in
                done.resume(returning: error?.localizedDescription ?? String(describing: result))
            }
        }
        print("WebKit diagnostic: \(diagnostic)")
        throw NSError(domain: "TopColor", code: 1, userInfo: [NSLocalizedDescriptionKey: "\(name): expected \(colour), got \(colours.last ?? "no message")"])
    }

    func run() async throws {
        // The visible wrapper is grey while html and theme metadata are black.
        // A normal header must extend into the clock area, just like a sticky one.
        web.loadHTMLString("""
          <!doctype html><meta name="viewport" content="width=device-width">
          <meta name="theme-color" content="#000000">
          <style>
          html { background: black } body { margin: 0; background: white }
          header { height: 100px; background: rgb(32,33,36); position: relative }
          #sign-in { position: absolute; left: 45%; width: 10%; height: 40px; background: rgb(168,218,255) }
          main { height: 2000px; background: rgb(70,70,70) }
          </style><header id="header"><div id="sign-in"></div></header><main></main>
          """, baseURL: nil)
        try await expect("rgb(32,33,36)", "visible header beats root background and centre button")
        try await evaluate("document.getElementById('header').style.backgroundColor = 'rgb(40,50,60)'; true")
        try await expect("rgb(40,50,60)", "dynamic header colour is observed without scrolling")
        try await evaluate("document.getElementById('header').style.position = 'sticky'; document.getElementById('header').style.top = '0'; window.scrollTo(0, 250); true")
        try await expect("rgb(40,50,60)", "sticky header remains continuous while scrolling")
        try await evaluate("document.getElementById('header').style.position = 'relative'; window.scrollTo(0, 250); true")
        try await expect("rgb(70,70,70)", "scrolling beyond a normal header follows the visible background")
        try await evaluate("window.scrollTo(0,0); document.getElementById('header').style.backgroundColor = 'white'; true")
        try await expect("rgb(255,255,255)", "a light header replaces the old dark colour")
        try await evaluate("document.getElementById('header').style.backgroundColor = 'rgb(18,18,18)'; true")
        try await expect("rgb(18,18,18)", "a dark-mode style change is reflected")
        let before = colours.count
        try await evaluate("document.querySelector('main').classList.add('unrelated'); window.dispatchEvent(new Event('search-top-refresh')); true")
        try await Task.sleep(nanoseconds: 150_000_000)
        guard colours.count == before else { throw NSError(domain: "TopColor", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unchanged colour sent duplicate messages"]) }
        print("PASS: unchanged colours do not send duplicate messages")
        window.close()
    }
}

@MainActor
final class Runner: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            do {
                let harness = TopColorHarness()
                try await harness.run()
                print("7 passed, 0 failed")
                exit(0)
            } catch {
                fputs("FAIL: \(error.localizedDescription)\n", stderr)
                exit(1)
            }
        }
    }
}

@main
struct TopColorTests {
    @MainActor static func main() {
        let app = NSApplication.shared
        let runner = Runner()
        app.delegate = runner
        app.run()
    }
}
