import SwiftUI
import WebKit

/// The page in front. One view that holds whichever tab's web view is
/// active, so switching tabs keeps every page as it was.
struct WebContainer: UIViewRepresentable {
    let tab: Tab

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .systemBackground
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        guard tab.web.superview !== view else { return }
        view.subviews.forEach { $0.removeFromSuperview() }
        tab.web.removeFromSuperview()
        tab.web.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tab.web)
        NSLayoutConstraint.activate([
            tab.web.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tab.web.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tab.web.topAnchor.constraint(equalTo: view.topAnchor),
            tab.web.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
}

/// What a tab shows before it has gone anywhere: the bookmarks, or nothing.
struct BlankPage: View {
    @EnvironmentObject var browser: Browser
    @EnvironmentObject var bookmarks: Bookmarks

    var body: some View {
        let sites = Bookmarks.sites(bookmarks.roots)
        ScrollView {
            if !sites.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 16)], spacing: 20) {
                    ForEach(sites.prefix(24)) { site in
                        Button {
                            if let url = site.url.flatMap(URL.init(string:)) { browser.active?.go(to: url) }
                        } label: {
                            VStack(spacing: 8) {
                                Text(String(Address.pretty(site.url.flatMap(URL.init(string:))).prefix(1)).uppercased())
                                    .font(.title2.weight(.semibold))
                                    .frame(width: 56, height: 56)
                                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 14))
                                Text(site.title)
                                    .font(.caption)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                }
                .padding(24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

/// The page area: the active tab's page, or its blank state.
struct PageArea: View {
    @EnvironmentObject var browser: Browser

    var body: some View {
        if let tab = browser.active {
            ZStack {
                // Under the clock too: a dark page shouldn't end in a white band.
                WebContainer(tab: tab).ignoresSafeArea(edges: .top)
                PageState(tab: tab)
            }
        } else {
            Color(.systemBackground)
        }
    }
}

private struct PageState: View {
    @ObservedObject var tab: Tab

    var body: some View {
        if tab.isBlank { BlankPage() }
    }
}
