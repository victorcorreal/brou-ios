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
            case .passwords: PasswordsView(site: browser.passwordSite)
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
            Text(keepable.user.isEmpty ? "It goes to iCloud Keychain, for Brou on your Mac too." : "\(keepable.user) — in iCloud Keychain, for Brou on your Mac too.")
        }
    }
}

// MARK: - iPhone

private struct Narrow: View {
    @EnvironmentObject var browser: Browser
    var body: some View {
        if let tab = browser.active {
            // A navigation stack only for the system's bars: on iPhone Duo's
            // outer screen they go along the side, under the clock.
            NavigationStack {
                NarrowTab(tab: tab).id(tab.id)
                    .toolbar(.hidden, for: .navigationBar)
            }
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
    /// How much of the screen the keyboard takes, as laid out: not from iOS's
    /// keyboard notices, which also fire when the device turns with none up,
    /// with the old orientation's frame and no notice that it hid. Brou's bar
    /// then stayed away for good.
    @State private var keyboard: CGFloat = 0

    /// The keyboard is up for one of the page's own fields, not ours. A
    /// hardware keyboard's bar alone leaves room for our bar.
    private var pageTyping: Bool { !focused && keyboard > 100 }

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
            // While the page is being typed in, the field and buttons step
            // aside, as Safari's do: the keyboard and its bar have taken half
            // the screen, more on iPhone Duo's outer one, and the page needs
            // what is left. The logins stay, right over the keyboard.
            if !tab.isBlank, !pageTyping {
                NarrowBar(tab: tab, typing: $typing, focused: $focused)
            }
        }
        .background { KeyboardReach { keyboard = $0 }.ignoresSafeArea() }
        .animation(.snappy, value: pageTyping)
        .modifier(SideButtons(tab: tab, prepare: { focused = false }))
    }
}

/// How far up the screen the keyboard reaches, from UIKit's keyboard layout
/// guide: laid out with the view, so always in the orientation on screen.
/// Spread over the whole screen, keyboard included.
private struct KeyboardReach: UIViewRepresentable {
    let changed: (CGFloat) -> Void

    func makeUIView(context: Context) -> Probe { Probe(changed: changed) }
    func updateUIView(_ probe: Probe, context: Context) { probe.changed = changed }

    final class Probe: UIView {
        var changed: (CGFloat) -> Void
        private var reach: CGFloat = 0

        init(changed: @escaping (CGFloat) -> Void) {
            self.changed = changed
            super.init(frame: .zero)
            isUserInteractionEnabled = false
            // With no keyboard the guide sits at the very bottom, with no
            // height, rather than over the home bar.
            keyboardLayoutGuide.usesBottomSafeArea = false
            // A view tied to the guide, so its changes lay this one out.
            let mark = UIView()
            mark.isHidden = true
            mark.translatesAutoresizingMaskIntoConstraints = false
            addSubview(mark)
            NSLayoutConstraint.activate([
                mark.leadingAnchor.constraint(equalTo: leadingAnchor),
                mark.widthAnchor.constraint(equalToConstant: 0),
                mark.topAnchor.constraint(equalTo: keyboardLayoutGuide.topAnchor),
                mark.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

        override func layoutSubviews() {
            super.layoutSubviews()
            let now = max(0, bounds.maxY - keyboardLayoutGuide.layoutFrame.minY)
            guard now != reach else { return }
            reach = now
            // Not during SwiftUI's own layout pass.
            DispatchQueue.main.async { [changed] in changed(now) }
        }
    }
}

/// The field under the page, and Brou's buttons under it unless iOS has them
/// in its vertical bar.
private struct NarrowBar: View {
    @Environment(\.buttonsAside) private var aside
    @ObservedObject var tab: Tab
    @Binding var typing: String
    @FocusState.Binding var focused: Bool

    var body: some View {
        VStack(spacing: 10) {
            AddressBar(tab: tab, typing: $typing, focused: $focused)
            if !focused, !aside { NarrowButtons(tab: tab) }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, focused || aside ? 8 : 2)
        .background(.bar)
    }
}

extension EnvironmentValues {
    /// Brou's buttons are in the system's vertical bar, so Brou's own bars
    /// and the start page's corner leave them out.
    @Entry var buttonsAside = false
}

/// Where iOS has a vertical bar — iPhone Duo's outer screen, and the Duo open
/// on its side — Brou's buttons go in it, as Apple asks: iOS never moves a
/// bar an app draws itself. Everywhere else, and before iOS 27.1, they stay
/// in Brou's own bar. The wide layout has its tabs and bookmarks in the
/// sidebar, so it puts New Tab there instead.
private struct SideButtons: ViewModifier {
    @ObservedObject var tab: Tab
    var wide = false
    let prepare: () -> Void

    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content.modifier(VerticalBar(tab: tab, wide: wide, prepare: prepare))
        } else {
            content
        }
    }
}

/// Back at the top, where Apple puts navigation. The menu, which holds the
/// most, last, and the last to give way when the bar runs out of room. Each
/// one has a title for when iOS lists it in the bar's overflow.
@available(iOS 27.1, *)
private struct VerticalBar: ViewModifier {
    @EnvironmentObject var browser: Browser
    @Environment(\.toolbarVerticalEdge) private var edge
    @ObservedObject var tab: Tab
    let wide: Bool
    let prepare: () -> Void

    func body(content: Content) -> some View {
        content
            .environment(\.buttonsAside, edge != nil)
            .toolbar {
                if edge != nil {
                    if !tab.isBlank {
                        ToolbarItem(placement: .bottomBar) {
                            Button { tab.back() } label: { Label("Back", systemImage: "chevron.backward") }
                                .disabled(!tab.canGoBack)
                        }
                        .axisBehavior(.verticalPreferred)
                        .visibilityPriority(.high)
                        ToolbarItem(placement: .bottomBar) {
                            Button { tab.forward() } label: { Label("Forward", systemImage: "chevron.forward") }
                                .disabled(!tab.canGoForward)
                        }
                        .axisBehavior(.verticalPreferred)
                    }
                    if wide {
                        ToolbarItem(placement: .bottomBar) {
                            Button { browser.newTab() } label: { Label("New Tab", systemImage: "plus") }
                        }
                        .axisBehavior(.verticalPreferred)
                    } else {
                        ToolbarItem(placement: .bottomBar) {
                            Button { prepare(); browser.sheet = .bookmarks } label: { Label("Bookmarks", systemImage: "book") }
                        }
                        .axisBehavior(.verticalPreferred)
                        ToolbarItem(placement: .bottomBar) {
                            Button { prepare(); browser.sheet = .tabs } label: { Label("Tabs", systemImage: "square.on.square") }
                                .badge(browser.tabs.count)
                        }
                        .axisBehavior(.verticalPreferred)
                    }
                    ToolbarItem(placement: .bottomBar) {
                        PageMenu(tab: tab, startPage: tab.isBlank, inBar: true, prepare: prepare)
                    }
                    .axisBehavior(.verticalPreferred)
                    .visibilityPriority(.high)
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
    @State private var room = TopRoom()

    var body: some View {
        VStack(spacing: 0) {
            WideBar(tab: tab, typing: $typing, focused: $focused, room: room)
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
        // The bar's colour goes up to the edge, behind the clock; TopRoom
        // says where its buttons go.
        .ignoresSafeArea(.container, edges: .top)
        .onGeometryChange(for: TopRoom.self) { TopRoom($0) } action: { room = $0 }
        .modifier(SideButtons(tab: tab, wide: true, prepare: { focused = false }))
    }
}

/// The bar along the top beside the sidebar: the field, with Brou's buttons
/// round it unless iOS has them in its vertical bar.
private struct WideBar: View {
    @EnvironmentObject var browser: Browser
    @Environment(\.buttonsAside) private var aside
    @ObservedObject var tab: Tab
    @Binding var typing: String
    @FocusState.Binding var focused: Bool
    let room: TopRoom

    var body: some View {
        HStack(spacing: 14) {
            if !aside {
                Button { tab.back() } label: { Image(systemName: "chevron.backward") }
                    .disabled(!tab.canGoBack)
                    .accessibilityLabel("Back")
                Button { tab.forward() } label: { Image(systemName: "chevron.forward") }
                    .disabled(!tab.canGoForward)
                    .accessibilityLabel("Forward")
            }
            if tab.isBlank {
                Spacer()
            } else {
                AddressBar(tab: tab, typing: $typing, focused: $focused)
            }
            if !aside {
                if !tab.isBlank { PageMenu(tab: tab) }
                Button { browser.newTab() } label: { Image(systemName: "plus") }
                    .accessibilityLabel("New Tab")
            }
        }
        .font(.title3)
        .padding(.leading, room.leading)
        .padding(.trailing, room.trailing)
        .padding(.top, room.top)
        .padding(.bottom, 8)
        .background(tab.isBlank ? AnyShapeStyle(Palette.ground) : AnyShapeStyle(.bar))
    }
}

/// Where the wide layout's bar puts its buttons at the top of the screen.
private struct TopRoom: Equatable {
    var top: CGFloat = 8
    var leading: CGFloat = 16
    var trailing: CGFloat = 16

    init() {}

    init(_ proxy: GeometryProxy) {
        let status = proxy.safeAreaInsets.top
        // Level with the clock, where the status bar is beside the page: on
        // iPhone Duo open on its side, or an iPhone on its side.
        guard status > 0 else { top = 20; return }
        // Under the status bar, as on iPad.
        top = status + 8
        guard #available(iOS 27.1, *),
              let corner = proxy.reservedRegions(kind: .occlusion).first(where: { $0.isActive && $0.frame.minY <= 0 })
        else { return }
        // iPhone Duo open upright: the camera and the clock hold one corner
        // of the band iOS keeps above the page. The buttons go up into the
        // rest of that band, level with the clock, and stop short of the
        // corner. The clock and Wi-Fi reach about 40 points out of the
        // camera's region, so they get 52 more.
        top = 20
        if corner.frame.midX > proxy.size.width / 2 {
            trailing = max(trailing, proxy.size.width - corner.frame.minX + 52)
        } else {
            leading = max(leading, corner.frame.maxX + 52)
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
        .navigationTitle("Brou")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { browser.sheet = .bookmarks } label: { Label("Edit Bookmarks", systemImage: "book") }
                    Button { browser.showPasswords() } label: { Label("Passwords", systemImage: "key") }
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
