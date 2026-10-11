import SwiftUI

@main
struct SearchApp: App {
    @StateObject private var browser = Browser()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(browser)
                .environmentObject(browser.bookmarks)
                .environmentObject(browser.history)
        }
        .onChange(of: phase) { _, now in
            if now == .background { browser.saveSession() }
        }
    }
}
