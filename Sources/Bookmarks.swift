import Foundation

// Bookmarks: folders and sites, the same model and the same file as Search
// for Mac's, and the same records in iCloud (CloudSync.swift).

struct Bookmark: Codable, Identifiable, Hashable {
    var id = UUID()
    var title: String
    /// Nil for a folder.
    var url: String?
    var children: [Bookmark]?

    var isFolder: Bool { url == nil }

    static func site(_ title: String, _ url: URL) -> Bookmark {
        Bookmark(title: title.isEmpty ? Address.pretty(url) : title, url: url.absoluteString, children: nil)
    }

    static func folder(_ title: String, _ children: [Bookmark] = []) -> Bookmark {
        Bookmark(title: title, url: nil, children: children)
    }
}

@MainActor
final class Bookmarks: ObservableObject {
    @Published private(set) var roots: [Bookmark] = []

    init() {
        load()
        CloudSync.start(self)
    }

    var count: Int { Bookmarks.sites(roots).count }

    nonisolated static func sites(_ nodes: [Bookmark]) -> [Bookmark] {
        nodes.flatMap { $0.isFolder ? sites($0.children ?? []) : [$0] }
    }

    func contains(_ url: URL) -> Bool {
        Bookmarks.sites(roots).contains { $0.url == url.absoluteString }
    }

    /// What a folder holds, or the top level for nil.
    func children(of folder: Bookmark.ID?) -> [Bookmark] {
        guard let folder else { return roots }
        return find(folder)?.children ?? []
    }

    func find(_ id: Bookmark.ID) -> Bookmark? {
        func walk(_ nodes: [Bookmark]) -> Bookmark? {
            for node in nodes {
                if node.id == id { return node }
                if let found = walk(node.children ?? []) { return found }
            }
            return nil
        }
        return walk(roots)
    }

    /// Every folder, each with how deep it sits, for "move to".
    func folders() -> [(node: Bookmark, depth: Int)] {
        func walk(_ nodes: [Bookmark], _ depth: Int) -> [(node: Bookmark, depth: Int)] {
            nodes.flatMap { node -> [(node: Bookmark, depth: Int)] in
                guard node.isFolder else { return [] }
                return [(node, depth)] + walk(node.children ?? [], depth + 1)
            }
        }
        return walk(roots, 0)
    }

    // MARK: - changing

    func add(_ url: URL, title: String, into folder: Bookmark.ID? = nil) {
        guard !contains(url) else { return }
        insert(.site(title, url), into: folder)
    }

    func addFolder(_ title: String, into folder: Bookmark.ID? = nil) {
        let name = title.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        insert(.folder(name), into: folder)
    }

    func remove(_ id: Bookmark.ID) {
        roots = Bookmarks.prune(id, from: roots)
        save()
    }

    func remove(url: URL) {
        guard let site = Bookmarks.sites(roots).first(where: { $0.url == url.absoluteString }) else { return }
        remove(site.id)
    }

    func rename(_ id: Bookmark.ID, to title: String) {
        let name = title.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        func walk(_ nodes: inout [Bookmark]) -> Bool {
            for i in nodes.indices {
                if nodes[i].id == id { nodes[i].title = name; return true }
                guard var kids = nodes[i].children else { continue }
                if walk(&kids) { nodes[i].children = kids; return true }
            }
            return false
        }
        var nodes = roots
        if walk(&nodes) { roots = nodes; save() }
    }

    /// Into another folder, or the top level for nil, at the end.
    func move(_ id: Bookmark.ID, into folder: Bookmark.ID?) {
        guard id != folder, let node = find(id) else { return }
        if let folder, Bookmarks.holds(folder, node) { return }
        var nodes = Bookmarks.prune(id, from: roots)
        guard Bookmarks.place(node, in: folder, nodes: &nodes) else { return }
        roots = nodes
        save()
    }

    /// Reordered within one folder (a list's drag).
    func reorder(in folder: Bookmark.ID?, from source: IndexSet, to destination: Int) {
        var kids = children(of: folder)
        kids.move(fromOffsets: source, toOffset: destination)
        if let folder {
            func walk(_ nodes: inout [Bookmark]) -> Bool {
                for i in nodes.indices {
                    if nodes[i].id == folder { nodes[i].children = kids; return true }
                    guard var inner = nodes[i].children else { continue }
                    if walk(&inner) { nodes[i].children = inner; return true }
                }
                return false
            }
            var nodes = roots
            guard walk(&nodes) else { return }
            roots = nodes
        } else {
            roots = kids
        }
        save()
    }

    /// The whole list as iCloud has it (see CloudSync.swift).
    func adopt(_ nodes: [Bookmark]) {
        guard nodes != roots else { return }
        roots = nodes
        save()
    }

    private func insert(_ node: Bookmark, into folder: Bookmark.ID?) {
        var nodes = roots
        if !Bookmarks.place(node, in: folder, nodes: &nodes) { nodes.append(node) }
        roots = nodes
        save()
    }

    private static func prune(_ id: Bookmark.ID, from nodes: [Bookmark]) -> [Bookmark] {
        nodes.compactMap { node in
            if node.id == id { return nil }
            var copy = node
            if let kids = node.children { copy.children = prune(id, from: kids) }
            return copy
        }
    }

    @discardableResult
    private static func place(_ node: Bookmark, in folder: Bookmark.ID?, nodes: inout [Bookmark]) -> Bool {
        guard let folder else { nodes.append(node); return true }
        for i in nodes.indices {
            if nodes[i].id == folder, nodes[i].isFolder {
                nodes[i].children = (nodes[i].children ?? []) + [node]
                return true
            }
            guard var kids = nodes[i].children else { continue }
            if place(node, in: folder, nodes: &kids) { nodes[i].children = kids; return true }
        }
        return false
    }

    /// Whether `id` is `node` or inside it.
    private static func holds(_ id: Bookmark.ID, _ node: Bookmark) -> Bool {
        node.id == id || (node.children ?? []).contains { holds(id, $0) }
    }

    // MARK: - the file

    private static var file: URL { Store.file("bookmarks.json") }

    private func load() {
        guard let data = try? Data(contentsOf: Bookmarks.file),
              let list = try? JSONDecoder().decode([Bookmark].self, from: data)
        else { return }
        roots = list
    }

    private func save() {
        Store.write(Bookmarks.file, try? JSONEncoder().encode(roots))
        CloudSync.shared?.changed()
    }
}
