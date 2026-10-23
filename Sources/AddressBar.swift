import SwiftUI

/// The one field: an address or words. Nothing written in it while it is
/// empty, as in Victor's Search for Mac. The site's name while a page is up;
/// the whole address once you touch it.
struct AddressBar: View {
    @EnvironmentObject var browser: Browser
    @ObservedObject var tab: Tab
    @Binding var typing: String
    @FocusState.Binding var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            if tab.reading {
                Image(systemName: "doc.plaintext").foregroundStyle(.secondary)
            }
            TextField("", text: $typing)
                .keyboardType(.webSearch)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.go)
                .focused($focused)
                .multilineTextAlignment(focused ? .leading : .center)
                .onSubmit {
                    browser.go(typing)
                    focused = false
                }
            if focused, !typing.isEmpty {
                Button { typing = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Clear")
            } else if !tab.isBlank {
                Button { tab.loading ? tab.web.stopLoading() : tab.reload() } label: {
                    Image(systemName: tab.loading ? "xmark" : "arrow.clockwise")
                }
                .foregroundStyle(.secondary)
                .accessibilityLabel(tab.loading ? "Stop" : "Reload")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(.regularMaterial, in: Capsule())
        .overlay(alignment: .bottom) {
            if tab.loading {
                GeometryReader { geo in
                    Capsule().fill(.tint).frame(width: geo.size.width * tab.progress, height: 2)
                }
                .frame(height: 2)
                .padding(.horizontal, 18)
            }
        }
        .onChange(of: focused) { _, now in
            typing = now ? (tab.url?.absoluteString ?? "") : Address.pretty(tab.url)
        }
        .onChange(of: tab.url) { _, url in
            if !focused { typing = Address.pretty(url) }
        }
        .onChange(of: browser.activeID) { _, _ in
            if !focused { typing = Address.pretty(browser.active?.url) }
        }
        .onAppear {
            typing = Address.pretty(tab.url)
            if tab.isBlank { focused = true }
        }
    }
}

/// While typing: what you have been to and kept that matches.
struct Suggestions: View {
    @EnvironmentObject var browser: Browser
    @EnvironmentObject var history: History
    @EnvironmentObject var bookmarks: Bookmarks
    let typed: String
    let picked: () -> Void

    var body: some View {
        let words = typed.lowercased()
        let kept = Bookmarks.sites(bookmarks.roots).filter {
            !words.isEmpty && (($0.url ?? "").lowercased().contains(words) || $0.title.lowercased().contains(words))
        }.prefix(3)
        let been = history.matches(typed).filter { visit in !kept.contains { $0.url == visit.url } }
        if !kept.isEmpty || !been.isEmpty {
            let rows = VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(kept)) { site in
                    row(icon: "bookmark", title: site.title, url: site.url ?? "")
                }
                ForEach(been, id: \.self) { visit in
                    row(icon: "clock", title: visit.title.isEmpty ? visit.url : visit.title, url: visit.url)
                }
            }
            // All of them when they fit over the keyboard; scrolled when it
            // leaves less room, as on iPhone Duo's outer screen on its side.
            ViewThatFits(in: .vertical) {
                rows
                ScrollView { rows }
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func row(icon: String, title: String, url: String) -> some View {
        Button {
            if let address = URL(string: url) { (browser.active ?? browser.newTab()).go(to: address) }
            picked()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon).foregroundStyle(.secondary).frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).lineLimit(1)
                    Text(Address.pretty(URL(string: url))).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .foregroundStyle(.primary)
    }
}

/// The logins kept for the site whose sign-in box was just touched. The key
/// opens them in the passwords sheet, to see or delete one.
struct LoginStrip: View {
    @EnvironmentObject var browser: Browser

    var body: some View {
        if !browser.offered.isEmpty {
            HStack(spacing: 8) {
                Button { browser.showPasswords() } label: { Image(systemName: "key.fill") }
                    .accessibilityLabel("Passwords for This Site")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(browser.offered) { login in
                            Button(name(of: login)) { browser.fill(login) }
                                .buttonStyle(.bordered)
                                .buttonBorderShape(.capsule)
                        }
                    }
                }
                Button { browser.offered = [] } label: { Image(systemName: "xmark") }
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Dismiss")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.bar)
        }
    }

    /// The user name; with the host too when another login has the same one.
    private func name(of login: Kept) -> String {
        guard !login.user.isEmpty else { return login.host }
        let twins = browser.offered.filter { $0.user == login.user }
        return twins.count > 1 && Set(twins.map(\.host)).count > 1 ? "\(login.user) · \(login.host)" : login.user
    }
}

/// What can be done to the page in front.
struct PageMenu: View {
    @EnvironmentObject var browser: Browser
    @EnvironmentObject var bookmarks: Bookmarks
    @ObservedObject var tab: Tab
    var startPage = false
    var prepare: () -> Void = {}

    var body: some View {
        Menu {
            if startPage {
                Button { prepare(); browser.sheet = .bookmarks } label: {
                    Label("Bookmarks", systemImage: "bookmark")
                }
                Button { prepare(); browser.sheet = .tabs } label: {
                    Label("Tabs", systemImage: "square.on.square")
                }
                Button { browser.newTab() } label: {
                    Label("New Tab", systemImage: "plus")
                }
                Divider()
            }
            Button {
                browser.toggleReader()
            } label: {
                Label(tab.reading ? "Leave Reading Mode" : "Reading Mode", systemImage: "doc.plaintext")
            }
            .disabled(tab.isBlank)
            Toggle(isOn: $browser.darkPages) { Label("Dark Pages", systemImage: "moon") }
            Toggle(isOn: $browser.textOnly) { Label("Text Only in Reading Mode", systemImage: "textformat") }
            Divider()
            if let url = tab.url {
                Button {
                    browser.toggleBookmark()
                } label: {
                    Label(bookmarks.contains(url) ? "Remove Bookmark" : "Add Bookmark",
                          systemImage: bookmarks.contains(url) ? "bookmark.slash" : "bookmark")
                }
                Button { share(url) } label: { Label("Share", systemImage: "square.and.arrow.up") }
                Button {
                    UIPasteboard.general.url = url
                    browser.say("Address copied")
                } label: {
                    Label("Copy Address", systemImage: "link")
                }
            }
            Divider()
            Button { prepare(); browser.showPasswords() } label: { Label("Passwords", systemImage: "key") }
            Button { prepare(); browser.sheet = .settings } label: { Label("Settings", systemImage: "gearshape") }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel(startPage ? "Menu" : "Page")
        .background(AnchorView(anchor: anchor))
    }

    @State private var anchor = Anchor()

    /// The system's share sheet, with the page itself among what it gets: with
    /// Apple's browser entitlement, iOS then offers Add to Home Screen.
    private func share(_ url: URL) {
        guard let view = anchor.view else { return }
        var top = view.window?.rootViewController
        while let next = top?.presentedViewController { top = next }
        let sheet = UIActivityViewController(activityItems: [url, tab.web], applicationActivities: nil)
        sheet.popoverPresentationController?.sourceView = view
        sheet.popoverPresentationController?.sourceRect = view.bounds
        top?.present(sheet, animated: true)
    }
}

/// Where the share sheet comes from: on the iPad, it points at the menu.
private final class Anchor {
    weak var view: UIView?
}

private struct AnchorView: UIViewRepresentable {
    let anchor: Anchor

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        anchor.view = view
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {}
}
