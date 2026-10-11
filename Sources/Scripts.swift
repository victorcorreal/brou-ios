import Foundation

// The page scripts, from Resources/JS: the same code as Search for Mac's
// DarkPages.swift, Reader.swift and ReaderText.swift, by way of Penumbra
// (see NOTICE).

enum Scripts {
    private static func load(_ name: String) -> String {
        guard let url = Bundle.main.url(forResource: name, withExtension: "js"),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else { return "" }
        return text
    }

    /// Dark Pages: in at document start, main frame only.
    static let dark = load("dark")
    static let darkOff = "window.__penumbraDark && window.__penumbraDark.off(); true"

    /// Reading mode: the article, then (if wanted) only its words, then the
    /// phone's viewport and Dark Pages looking again.
    static let reader = load("reader")
    static let textOnly = load("text-only")
    static let readerAfter = load("reader-after")
}
