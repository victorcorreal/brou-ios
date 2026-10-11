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

/// What a tab shows before it has gone anywhere, as on the Mac: the one
/// field, alone, a little above the middle, nothing written in it.
struct BlankPage: View {
    @EnvironmentObject var browser: Browser
    @Binding var typing: String
    @FocusState.Binding var focused: Bool

    var body: some View {
        GeometryReader { geo in
            VStack {
                Spacer()
                field
                    .frame(maxWidth: min(560, max(0, geo.size.width - 28)))
                    .overlay(alignment: .top) {
                        if focused, !typing.isEmpty {
                            Suggestions(typed: typing) { focused = false }
                                .frame(maxWidth: min(560, max(0, geo.size.width - 28)))
                                .offset(y: 62)
                        }
                    }
                Spacer()
            }
            // Lifted a little above centre: dead centre reads as low.
            .padding(.bottom, 60)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.ground.ignoresSafeArea())
        .onAppear { focused = true }
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
            WebContainer(tab: tab).ignoresSafeArea(edges: .top)
            if tab.isBlank { BlankPage(typing: $typing, focused: $focused) }
        }
    }
}
