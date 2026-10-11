import Foundation

// What was typed in the one field: an address to go to, or words to search.

enum Address {
    static func url(from text: String) -> URL? {
        let typed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !typed.isEmpty else { return nil }
        if typed.contains(" ") { return search(typed) }
        if let url = URL(string: typed), let scheme = url.scheme?.lowercased(),
           ["http", "https"].contains(scheme), url.host() != nil {
            return url
        }
        // example.com, a.b.example/path, localhost:3000, 192.168.1.1
        let looksLikeHost = #"^(localhost|[\w-]+(\.[\w-]+)+)(:\d+)?([/?#].*)?$"#
        if typed.range(of: looksLikeHost, options: .regularExpression) != nil,
           let url = URL(string: "https://" + typed) {
            return url
        }
        return search(typed)
    }

    static func search(_ text: String) -> URL? {
        var parts = URLComponents(string: "https://www.google.com/search")!
        parts.queryItems = [URLQueryItem(name: "q", value: text)]
        return parts.url
    }

    /// The site, as the field shows it while nothing is being typed.
    static func pretty(_ url: URL?) -> String {
        guard let url else { return "" }
        guard let host = url.host() else { return url.absoluteString }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}
