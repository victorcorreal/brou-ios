import SwiftUI
import WebKit

// The browser: its tabs, which one is in front, and what it is offering.

@MainActor
final class Browser: ObservableObject {
    @Published private(set) var tabs: [Tab] = []
    @Published var activeID: UUID?

    /// Every page dark, whatever its own colours (Dark Pages, as on the Mac).
    @Published var darkPages: Bool {
        didSet {
            Store.settings.set(darkPages, forKey: "pages.dark")
            tabs.forEach { $0.applyDark(darkPages) }
        }
    }

    /// Reading mode keeps the words and nothing else. On unless turned off.
    @Published var textOnly: Bool {
        didSet { Store.settings.set(textOnly, forKey: "reader.textOnly") }
    }

    /// The sheet in front, if any.
    enum Sheet: String, Identifiable {
        case tabs, bookmarks, passwords, settings
        var id: String { rawValue }
    }
    @Published var sheet: Sheet?
    /// The site whose passwords the sheet shows; nil for all of them.
    @Published var passwordSite: String?

    /// Logins for the sign-in box the page has just touched.
    @Published var offered: [Kept] = []
    /// A password the page has just sent, waiting for "keep it?".
    @Published var toKeep: Keepable?
    /// A line said at the foot of the window for a moment.
    @Published var said: String?

    struct Keepable: Identifiable {
        let host: String
        let user: String
        let password: String
        let clear: Bool
        var id: String { host + "\u{1}" + user }
    }

    let bookmarks = Bookmarks()
    let history = History()

    var active: Tab? { tabs.first { $0.id == activeID } ?? tabs.last }

    init() {
        darkPages = Store.settings.bool(forKey: "pages.dark")
        textOnly = Store.settings.object(forKey: "reader.textOnly") as? Bool ?? true
        Shield.shared.compile()
        restoreSession()
        // Start with bookmarks; keep the prior session's pages in their tabs.
        if let blank = tabs.last(where: \.isBlank) { activeID = blank.id }
        else { newTab() }
    }

    // MARK: - tabs

    @discardableResult
    func newTab(_ url: URL? = nil) -> Tab {
        let tab = Tab(browser: self)
        tabs.append(tab)
        activeID = tab.id
        if let url { tab.go(to: url) }
        saveSession()
        return tab
    }

    /// For a link that wants a window of its own: WebKit's configuration, a tab in front.
    func open(configuration: WKWebViewConfiguration) -> Tab {
        let tab = Tab(browser: self, configuration: configuration)
        tabs.append(tab)
        activeID = tab.id
        return tab
    }

    /// A link from another app, or a Home Screen bookmark, once Search is the
    /// default browser: the tab that already shows it, the empty one in
    /// front, or a new one.
    func open(_ url: URL) {
        guard ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return }
        sheet = nil
        if let showing = tabs.first(where: { $0.url == url }) { return select(showing) }
        if let tab = active, tab.isBlank { tab.go(to: url) } else { newTab(url) }
    }

    func select(_ tab: Tab) {
        activeID = tab.id
        offered = []
    }

    func close(_ tab: Tab) {
        guard let index = tabs.firstIndex(where: { $0.id == tab.id }) else { return }
        tabs.remove(at: index)
        tab.web.stopLoading()
        if tabs.isEmpty { newTab() }
        if activeID == tab.id { activeID = tabs[min(index, tabs.count - 1)].id }
        saveSession()
    }

    func closeAll() {
        tabs.forEach { $0.web.stopLoading() }
        tabs = []
        newTab()
    }

    /// The one field: an address, or words to search for.
    func go(_ text: String) {
        guard let url = Address.url(from: text) else { return }
        (active ?? newTab()).go(to: url)
    }

    // MARK: - the page

    func toggleReader() {
        guard let tab = active, !tab.isBlank else { return }
        tab.toggleReader(textOnly: textOnly) { [weak self] worked in
            if !worked { self?.say("Nothing to read on this page") }
        }
    }

    func toggleBookmark() {
        guard let tab = active, let url = tab.url else { return }
        if bookmarks.contains(url) {
            bookmarks.remove(url: url)
            say("Bookmark removed")
        } else {
            bookmarks.add(url, title: tab.title)
            say("Bookmarked")
        }
    }

    func say(_ line: String) {
        said = line
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            if self?.said == line { self?.said = nil }
        }
    }

    // MARK: - sign-ins

    func offerLogins(for tab: Tab) {
        guard tab.id == active?.id, let url = tab.url, let host = url.host() else { return }
        offered = Vault.kept(for: host).filter { url.scheme?.lowercased() != "http" || $0.clear }
    }

    func dismissLogins(for tab: Tab) {
        if tab.id == active?.id { offered = [] }
    }

    func fill(_ kept: Kept) {
        guard let tab = active, let url = tab.url, let host = url.host(),
              Vault.passwordHost(host) == kept.host,
              url.scheme?.lowercased() != "http" || kept.clear else { offered = []; return }
        offered = []
        guard let login = Vault.login(kept) else { say("The keychain refused it"); return }
        tab.fill(login)
    }

    /// The page host stays selected even when it has no saved account.
    /// The explicit Show All action opens the full vault.
    func showPasswords() {
        let host = active?.url?.host()
        passwordSite = host.map(Vault.passwordHost)
        sheet = .passwords
    }

    /// A password just deleted is no longer offered.
    func forgot(_ kept: Kept) {
        offered.removeAll { $0.id == kept.id }
    }

    func offerToKeep(user: String, password: String, from tab: Tab) {
        guard let url = tab.url, let host = url.host(), !password.isEmpty else { return }
        let site = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        guard !Vault.holds(host: site, user: user, password: password),
              !Vault.isNever(site), toKeep?.id != site + "\u{1}" + user
        else { return }
        toKeep = Keepable(host: site, user: user, password: password, clear: url.scheme?.lowercased() == "http")
    }

    func keep(_ keepable: Keepable) {
        Vault.save(host: keepable.host, user: keepable.user, password: keepable.password, used: Date(), clear: keepable.clear)
        toKeep = nil
        say("Password saved")
    }

    // MARK: - the session

    private struct Saved: Codable {
        var urls: [String]
        var active: Int
    }

    func saveSession() {
        let urls = tabs.map { $0.url?.absoluteString ?? "" }
        let index = tabs.firstIndex { $0.id == activeID } ?? max(0, tabs.count - 1)
        Store.write(Store.file("session.json"), try? JSONEncoder().encode(Saved(urls: urls, active: index)))
    }

    private func restoreSession() {
        guard let data = try? Data(contentsOf: Store.file("session.json")),
              let saved = try? JSONDecoder().decode(Saved.self, from: data)
        else { return }
        for text in saved.urls {
            let tab = Tab(browser: self)
            tabs.append(tab)
            if let url = URL(string: text), !text.isEmpty { tab.go(to: url) }
        }
        if tabs.indices.contains(saved.active) { activeID = tabs[saved.active].id }
    }
}

extension Vault {
    /// Sites that asked not to be asked again.
    static func isNever(_ host: String) -> Bool {
        (Store.settings.stringArray(forKey: "passwords.never") ?? []).contains(host)
    }

    static func never(_ host: String) {
        var hosts = Store.settings.stringArray(forKey: "passwords.never") ?? []
        if !hosts.contains(host) { hosts.append(host) }
        Store.settings.set(hosts, forKey: "passwords.never")
    }
}

/// Where you have been, for the field's suggestions. On this phone only, for now.
@MainActor
final class History: ObservableObject {
    struct Visit: Codable, Hashable {
        var url: String
        var title: String
        var when: Date
    }

    @Published private(set) var visits: [Visit] = []
    private static var file: URL { Store.file("history.json") }

    init() {
        if let data = try? Data(contentsOf: History.file),
           let list = try? JSONDecoder().decode([Visit].self, from: data) {
            visits = list
        }
    }

    func visit(url: URL?, title: String?) {
        guard let url, ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return }
        visits.removeAll { $0.url == url.absoluteString }
        visits.insert(Visit(url: url.absoluteString, title: title ?? "", when: Date()), at: 0)
        if visits.count > 1000 { visits.removeLast(visits.count - 1000) }
        Store.write(History.file, try? JSONEncoder().encode(visits))
    }

    /// What starts with, or holds, what was typed: the latest first.
    func matches(_ text: String, limit: Int = 6) -> [Visit] {
        let typed = text.lowercased().trimmingCharacters(in: .whitespaces)
        guard !typed.isEmpty else { return [] }
        return Array(visits.filter { visit in
            let bare = visit.url.lowercased()
                .replacingOccurrences(of: "https://", with: "")
                .replacingOccurrences(of: "http://", with: "")
                .replacingOccurrences(of: "www.", with: "")
            return bare.hasPrefix(typed) || visit.title.lowercased().contains(typed)
        }.prefix(limit))
    }

    func clear() {
        visits = []
        Store.write(History.file, try? JSONEncoder().encode(visits))
    }
}
