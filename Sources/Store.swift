import Foundation

// Where everything this app keeps is kept: one folder in Application Support,
// as Search for Mac keeps its own.

enum Store {
    static let folder: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Search", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }()

    static func file(_ name: String) -> URL {
        folder.appendingPathComponent(name)
    }

    static func write(_ file: URL, _ data: Data?) {
        guard let data else { return }
        try? data.write(to: file, options: .atomic)
    }

    static let settings = UserDefaults.standard
}

extension Store {
    /// Search for Mac's test runs (see CloudSync.swift there). None here.
    static let testing = false
}
