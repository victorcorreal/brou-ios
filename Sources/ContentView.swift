import SwiftUI

/// iPhone (and the Duo folded): the page, and the field and buttons under it.
/// iPad (and the Duo open): a sidebar of tabs and bookmarks beside the page,
/// as Search on the Mac.
struct ContentView: View {
    @EnvironmentObject var browser: Browser
    @Environment(\.horizontalSizeClass) private var width

    var body: some View {
        Group {
            if width == .regular { Wide() } else { Narrow() }
        }
        .sheet(item: $browser.sheet) { sheet in
            switch sheet {
            case .tabs: TabsView()
            case .bookmarks: BookmarksView()
            case .passwords: PasswordsView()
            case .settings: SettingsView()
            }
        }
        .overlay(alignment: .top) {
            if let said = browser.said {
                Text(said)
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: browser.said)
        .alert(
            "Save password for \(browser.toKeep?.host ?? "")?",
            isPresented: Binding(get: { browser.toKeep != nil }, set: { if !$0 { browser.toKeep = nil } }),
            presenting: browser.toKeep
        ) { keepable in
            Button("Save") { browser.keep(keepable) }
            Button("Never for This Site") {
                Vault.never(keepable.host)
                browser.toKeep = nil
            }
            Button("Not Now", role: .cancel) { browser.toKeep = nil }
        } message: { keepable in
            Text(keepable.user.isEmpty ? "It goes to iCloud Keychain, for Search on your Mac too." : "\(keepable.user) — in iCloud Keychain, for Search on your Mac too.")
        }
    }
}

// MARK: - iPhone

private struct Narrow: View {
    @EnvironmentObject var browser: Browser
    var body: some View {
        if let tab = browser.active {
            NarrowTab(tab: tab).id(tab.id)
        } else {
            Palette.ground.ignoresSafeArea()
        }
    }
}

/// One tab on the iPhone. An empty one is the Mac's: the field in the middle,
/// and only the buttons under it.
private struct NarrowTab: View {
    @EnvironmentObject var browser: Browser
    @ObservedObject var tab: Tab
    @State private var typing = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            PageArea(tab: tab, typing: $typing, focused: $focused)
                .overlay(alignment: .bottom) {
                    if !tab.isBlank, focused, !typing.isEmpty {
                        Suggestions(typed: typing) { focused = false }
                            .padding(12)
                    }
                }
            LoginStrip()
            if !(tab.isBlank && focused) {
                VStack(spacing: 10) {
                    if !tab.isBlank { AddressBar(tab: tab, typing: $typing, focused: $focused) }
                    if !focused { NarrowButtons(tab: tab) }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, focused ? 8 : 2)
                .background(tab.isBlank ? AnyShapeStyle(Palette.ground) : AnyShapeStyle(.bar))
            }
        }
    }
}

private struct NarrowButtons: View {
    @EnvironmentObject var browser: Browser
    @ObservedObject var tab: Tab

    var body: some View {
        HStack {
            Button { tab.back() } label: { Image(systemName: "chevron.backward") }
                .disabled(!tab.canGoBack)
                .accessibilityLabel("Back")
            Spacer()
            Button { tab.forward() } label: { Image(systemName: "chevron.forward") }
                .disabled(!tab.canGoForward)
                .accessibilityLabel("Forward")
            Spacer()
            PageMenu(tab: tab)
            Spacer()
            Button { browser.sheet = .bookmarks } label: { Image(systemName: "book") }
                .accessibilityLabel("Bookmarks")
            Spacer()
            Button { browser.sheet = .tabs } label: { TabCount(count: browser.tabs.count) }
                .accessibilityLabel("Tabs")
        }
        .font(.title3)
        .padding(.horizontal, 12)
        .frame(height: 40)
    }
}

struct TabCount: View {
    let count: Int

    var body: some View {
        Text("\(count)")
            .font(.caption.weight(.bold))
            .frame(minWidth: 22, minHeight: 22)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(lineWidth: 1.6))
    }
}

// MARK: - iPad

private struct Wide: View {
    @EnvironmentObject var browser: Browser
    @State private var columns = NavigationSplitViewVisibility.all

    var body: some View {
        NavigationSplitView(columnVisibility: $columns) {
            Sidebar()
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 340)
        } detail: {
            Group {
                if let tab = browser.active {
                    WideTab(tab: tab).id(tab.id)
                } else {
                    Palette.ground
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

/// One tab beside the sidebar. An empty one has the field in the middle, as
/// on the Mac, and only the buttons along the top.
private struct WideTab: View {
    @EnvironmentObject var browser: Browser
    @ObservedObject var tab: Tab
    @State private var typing = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Button { tab.back() } label: { Image(systemName: "chevron.backward") }
                    .disabled(!tab.canGoBack)
                    .accessibilityLabel("Back")
                Button { tab.forward() } label: { Image(systemName: "chevron.forward") }
                    .disabled(!tab.canGoForward)
                    .accessibilityLabel("Forward")
                if tab.isBlank {
                    Spacer()
                } else {
                    AddressBar(tab: tab, typing: $typing, focused: $focused)
                }
                PageMenu(tab: tab)
                Button { browser.newTab() } label: { Image(systemName: "plus") }
                    .accessibilityLabel("New Tab")
            }
            .font(.title3)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(tab.isBlank ? AnyShapeStyle(Palette.ground) : AnyShapeStyle(.bar))
            LoginStrip()
            PageArea(tab: tab, typing: $typing, focused: $focused)
                .overlay(alignment: .top) {
                    if !tab.isBlank, focused, !typing.isEmpty {
                        Suggestions(typed: typing) { focused = false }
                            .frame(maxWidth: 560)
                            .padding(12)
                    }
                }
        }
    }
}

private struct Sidebar: View {
    @EnvironmentObject var browser: Browser
    @EnvironmentObject var bookmarks: Bookmarks

    var body: some View {
        List {
            Section("Tabs") {
                ForEach(browser.tabs) { tab in
                    SidebarTab(tab: tab)
                }
                Button { browser.newTab() } label: { Label("New Tab", systemImage: "plus") }
            }
            Section("Bookmarks") {
                if bookmarks.roots.isEmpty {
                    Text("None yet").foregroundStyle(.secondary)
                }
                OutlineGroup(bookmarks.roots, children: \.children) { node in
                    if node.isFolder {
                        Label(node.title, systemImage: "folder")
                    } else {
                        Button {
                            if let url = node.url.flatMap(URL.init(string:)) { (browser.active ?? browser.newTab()).go(to: url) }
                        } label: {
                            Label(node.title, systemImage: "bookmark")
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Search")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { browser.sheet = .bookmarks } label: { Label("Edit Bookmarks", systemImage: "book") }
                    Button { browser.sheet = .passwords } label: { Label("Passwords", systemImage: "key") }
                    Button { browser.sheet = .settings } label: { Label("Settings", systemImage: "gearshape") }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }
}

private struct SidebarTab: View {
    @EnvironmentObject var browser: Browser
    @ObservedObject var tab: Tab

    var body: some View {
        Button { browser.select(tab) } label: {
            HStack {
                Text(String(Address.pretty(tab.url).prefix(1)).uppercased())
                    .font(.caption.weight(.semibold))
                    .frame(width: 22, height: 22)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 5))
                Text(tab.isBlank ? "New Tab" : (tab.title.isEmpty ? Address.pretty(tab.url) : tab.title))
                    .lineLimit(1)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .foregroundStyle(.primary)
        .listRowBackground(browser.activeID == tab.id ? Color.accentColor.opacity(0.15) : nil)
        .swipeActions {
            Button(role: .destructive) { browser.close(tab) } label: { Label("Close", systemImage: "xmark") }
        }
    }
}
