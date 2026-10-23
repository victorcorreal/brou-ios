import SwiftUI
import WebKit

/// The page in front. One view that holds whichever tab's web view is
/// active, so switching tabs keeps every page as it was.
struct WebContainer: UIViewRepresentable {
    let tab: Tab
    /// Given as a value, not read from the tab: a change of colour is a
    /// change of this view, and SwiftUI then updates it.
    let band: UIColor

    /// The page goes on under the clock, so a dark page doesn't end in a
    /// white band; the band over it there is the page's colour, as in
    /// Safari, so what scrolls up passes under the clock and never shows
    /// over a page's own bar held at the top.
    final class Holder: UIView {
        let band = UIView()
    }

    func makeUIView(context: Context) -> Holder {
        let view = Holder()
        view.backgroundColor = .systemBackground
        view.band.isUserInteractionEnabled = false
        view.band.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(view.band)
        NSLayoutConstraint.activate([
            view.band.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            view.band.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            view.band.topAnchor.constraint(equalTo: view.topAnchor),
            view.band.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
        ])
        return view
    }

    func updateUIView(_ view: Holder, context: Context) {
        view.backgroundColor = band
        view.band.backgroundColor = band
        guard tab.web.superview !== view else { return }
        view.subviews.filter { $0 !== view.band }.forEach { $0.removeFromSuperview() }
        tab.web.removeFromSuperview()
        tab.web.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(tab.web, belowSubview: view.band)
        NSLayoutConstraint.activate([
            tab.web.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tab.web.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tab.web.topAnchor.constraint(equalTo: view.topAnchor),
            tab.web.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
}

/// What a tab shows before it has gone anywhere, as on the Mac: the one
/// field, alone, a little above the middle, nothing written in it.
struct BlankPage: View {
    @EnvironmentObject var browser: Browser
    @Environment(\.scenePhase) private var phase
    @ObservedObject var tab: Tab
    @Binding var typing: String
    @FocusState.Binding var focused: Bool
    /// The field's top, from the top of what the keyboard leaves.
    @State private var fieldTop: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            VStack {
                Spacer()
                field
                    .frame(maxWidth: min(560, max(0, geo.size.width - 28)))
                    .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named("blank")).minY } action: { fieldTop = $0 }
                    .overlay(alignment: .top) {
                        if focused, !typing.isEmpty {
                            // Under the field, down to the keyboard and no
                            // further; the rest scrolls.
                            let below: CGFloat = 62
                            Suggestions(typed: typing) { focused = false }
                                .frame(maxWidth: min(560, max(0, geo.size.width - 28)))
                                .frame(height: max(0, geo.size.height - fieldTop - below - 12), alignment: .top)
                                .offset(y: below)
                        }
                    }
                Spacer()
            }
            // Lifted a little above centre: dead centre reads as low.
            .padding(.bottom, 60)
            .frame(maxWidth: .infinity)
            .coordinateSpace(.named("blank"))
        }
        .background(Palette.ground.ignoresSafeArea())
        .overlay(alignment: .bottomTrailing) {
            PageMenu(tab: tab, startPage: true, prepare: { focused = false })
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.blue)
                .frame(width: 44, height: 44)
                .accessibilityIdentifier("start-menu-button")
                .padding(.trailing, 16)
                .padding(.bottom, 12)
        }
        .onAppear { focused = true }
        .onChange(of: phase) { _, now in
            if now == .active, browser.sheet == nil { focused = true }
        }
    }

    private var field: some View {
        TextField("", text: $typing)
            .font(.system(size: 17))
            .foregroundStyle(Palette.ink)
            .keyboardType(.webSearch)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.go)
            .focused($focused)
            .onSubmit {
                browser.go(typing)
                focused = false
            }
            .frame(height: 22)
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .background {
                ZStack {
                    Breath()
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.ground)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Palette.hairline, lineWidth: 1)
                    .allowsHitTesting(false)
            )
            .shadow(color: .black.opacity(0.06), radius: 24, y: 8)
    }
}

/// A slow, almost invisible breath under the empty tab's field, as on the
/// Mac: a glow of the text's colour, 0.97 to 1.03 of the field's size and
/// 65% to full, 2.6 s each way. A thing that never moves at all reads as a
/// picture of an app rather than an app.
private struct Breath: View {
    @State private var out = false

    var body: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(Palette.ground)
            .shadow(color: Palette.ink.opacity(0.07), radius: 26)
            .scaleEffect(out ? 1.03 : 0.97)
            .opacity(out ? 1 : 0.65)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) { out = true }
            }
    }
}

/// The page area: the tab's page, or its empty state.
struct PageArea: View {
    @ObservedObject var tab: Tab
    @Binding var typing: String
    @FocusState.Binding var focused: Bool

    var body: some View {
        ZStack {
            // Under the clock too: a dark page shouldn't end in a white band.
            WebContainer(tab: tab, band: tab.isBlank ? .clear : tab.shade ?? .systemBackground).ignoresSafeArea(edges: .top)
            if tab.isBlank { BlankPage(tab: tab, typing: $typing, focused: $focused) }
        }
    }
}
