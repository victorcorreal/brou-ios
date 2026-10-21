import CloudKit
import SwiftUI

// MARK: - tabs

struct TabsView: View {
    @EnvironmentObject var browser: Browser
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 14)], spacing: 14) {
                    ForEach(browser.tabs) { tab in
                        TabCard(tab: tab, front: tab.id == browser.activeID) {
                            browser.select(tab)
                            dismiss()
                        } close: {
                            browser.close(tab)
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle("\(browser.tabs.count) Tabs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close All", role: .destructive) {
                        browser.closeAll()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        browser.newTab()
                        dismiss()
                    } label: {
                        Label("New Tab", systemImage: "plus")
                    }
                }
            }
        }
    }
}

private struct TabCard: View {
    @ObservedObject var tab: Tab
    let front: Bool
    let open: () -> Void
    let close: () -> Void

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Text(tab.isBlank ? "New Tab" : (tab.title.isEmpty ? Address.pretty(tab.url) : tab.title))
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 4)
                    Button(action: close) { Image(systemName: "xmark.circle.fill") }
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Close")
                }
                Spacer(minLength: 0)
                Text(Address.pretty(tab.url))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(12)
            .frame(height: 110)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(front ? Color.accentColor : .clear, lineWidth: 2))
        }
        .foregroundStyle(.primary)
    }
}

// MARK: - bookmarks

struct BookmarksView: View {
    @EnvironmentObject var browser: Browser
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Folder(folder: nil, title: "Bookmarks", done: { dismiss() })
        }
    }
}

private struct Folder: View {
    @EnvironmentObject var browser: Browser
    @EnvironmentObject var bookmarks: Bookmarks
    let folder: Bookmark.ID?
    let title: String
    let done: () -> Void
    @State private var naming = false
    @State private var name = ""
    @State private var renaming: Bookmark?
    @State private var moving: Bookmark?

    var body: some View {
        let nodes = bookmarks.children(of: folder)
        List {
            if folder == nil, let tab = browser.active, let url = tab.url, !bookmarks.contains(url) {
                Button {
                    bookmarks.add(url, title: tab.title)
                } label: {
                    Label("Add \(Address.pretty(url))", systemImage: "plus")
                }
            }
            ForEach(nodes) { node in
                row(node)
                    .swipeActions {
                        Button(role: .destructive) { bookmarks.remove(node.id) } label: { Label("Delete", systemImage: "trash") }
                        Button { renaming = node; name = node.title } label: { Label("Rename", systemImage: "pencil") }
                            .tint(.gray)
                    }
                    .contextMenu {
                        Button { renaming = node; name = node.title } label: { Label("Rename", systemImage: "pencil") }
                        Button { moving = node } label: { Label("Move…", systemImage: "folder") }
                        Button(role: .destructive) { bookmarks.remove(node.id) } label: { Label("Delete", systemImage: "trash") }
                    }
            }
            .onMove { from, to in bookmarks.reorder(in: folder, from: from, to: to) }
            if nodes.isEmpty {
                Text(folder == nil ? "Bookmarks you keep here, on your Mac or on this phone, are in both through iCloud." : "Empty folder")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done", action: done)
            }
            ToolbarItem(placement: .bottomBar) {
                Button { naming = true; name = "" } label: { Label("New Folder", systemImage: "folder.badge.plus") }
            }
            ToolbarItem(placement: .bottomBar) {
                EditButton()
            }
        }
        .alert("New Folder", isPresented: $naming) {
            TextField("Name", text: $name)
            Button("Make") { bookmarks.addFolder(name, into: folder) }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Rename", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $name)
            Button("Rename") { if let node = renaming { bookmarks.rename(node.id, to: name) } }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: $moving) { node in
            MoveSheet(node: node)
        }
    }

    @ViewBuilder
    private func row(_ node: Bookmark) -> some View {
        if node.isFolder {
            NavigationLink {
                Folder(folder: node.id, title: node.title, done: done)
            } label: {
                Label(node.title, systemImage: "folder")
            }
        } else {
            Button {
                if let url = node.url.flatMap(URL.init(string:)) { (browser.active ?? browser.newTab()).go(to: url) }
                done()
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(node.title).lineLimit(1)
                    Text(Address.pretty(node.url.flatMap(URL.init(string:)))).font(.caption).foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.primary)
        }
    }
}

private struct MoveSheet: View {
    @EnvironmentObject var bookmarks: Bookmarks
    @Environment(\.dismiss) private var dismiss
    let node: Bookmark

    var body: some View {
        NavigationStack {
            List {
                Button("Top Level") { bookmarks.move(node.id, into: nil); dismiss() }
                ForEach(bookmarks.folders().filter { $0.node.id != node.id }, id: \.node.id) { entry in
                    Button {
                        bookmarks.move(node.id, into: entry.node.id)
                        dismiss()
                    } label: {
                        Label(entry.node.title, systemImage: "folder")
                            .padding(.leading, CGFloat(entry.depth) * 16)
                    }
                }
            }
            .navigationTitle("Move \u{201C}\(node.title)\u{201D}")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}

// MARK: - passwords

struct PasswordsView: View {
    @EnvironmentObject var browser: Browser
    @Environment(\.dismiss) private var dismiss
    /// Only this site's passwords (the page's, from the key); nil for all.
    @State private var site: String?
    @State private var kept: [Kept] = Vault.all()
    @State private var shown: [String: String] = [:]
    @State private var query = ""
    @State private var doomed: Kept?

    init(site: String? = nil) {
        _site = State(initialValue: site)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(listed) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.host).font(.body.weight(.medium))
                        Text(item.user.isEmpty ? "(no user name)" : item.user).foregroundStyle(.secondary)
                        Text(when(item)).font(.caption).foregroundStyle(.secondary)
                        if let secret = shown[item.id] {
                            HStack {
                                Text(secret).font(.body.monospaced()).textSelection(.enabled)
                                Spacer()
                                Button { UIPasteboard.general.string = secret } label: { Image(systemName: "doc.on.doc") }
                                    .buttonStyle(.borderless)
                                    .accessibilityLabel("Copy Password")
                            }
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { reveal(item) }
                    .swipeActions {
                        // Not role: .destructive, which takes the row away
                        // before the question is answered.
                        Button { doomed = item } label: { Label("Delete", systemImage: "trash") }
                            .tint(.red)
                    }
                    .contextMenu {
                        Button { UIPasteboard.general.string = item.user } label: { Label("Copy User Name", systemImage: "person") }
                        Button(role: .destructive) { doomed = item } label: { Label("Delete", systemImage: "trash") }
                    }
                }
                if let site, listed.isEmpty {
                    Text("No matching passwords for \(site).")
                        .foregroundStyle(.secondary)
                } else if kept.isEmpty {
                    Text("Passwords you save in Brou, on your Mac or on this phone, are in both through iCloud Keychain.")
                        .foregroundStyle(.secondary)
                }
                if site != nil {
                    Section {
                        Button("Show All Passwords") { site = nil }
                    } footer: {
                        Text("Tap one to see its password. Swipe left to delete it.")
                    }
                }
            }
            .searchable(text: $query)
            .navigationTitle(site ?? "Passwords")
            .navigationBarTitleDisplayMode(site == nil ? .automatic : .inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .refreshable { kept = Vault.all() }
            .confirmationDialog(
                "Delete the password for \(doomed?.user ?? "") at \(doomed?.host ?? "")?",
                isPresented: Binding(get: { doomed != nil }, set: { if !$0 { doomed = nil } }),
                titleVisibility: .visible,
                presenting: doomed
            ) { item in
                Button("Delete Password", role: .destructive) { forget(item) }
            } message: { _ in
                Text("It goes from Brou on this phone and on your Mac.")
            }
        }
    }

    /// The site's passwords, or all of them; then what the search field holds.
    private var listed: [Kept] {
        let words = query.lowercased()
        let pool = site.map { site in
            kept.filter { $0.host == site }
                .sorted { ($0.used ?? .distantPast) > ($1.used ?? .distantPast) }
        } ?? kept
        return pool.filter { words.isEmpty || $0.host.contains(words) || $0.user.lowercased().contains(words) }
    }

    /// When it was last used and saved: what tells two alike apart.
    private func when(_ item: Kept) -> String {
        var parts = [item.used.map { "Used \($0.formatted(date: .abbreviated, time: .omitted))" } ?? "Never used"]
        if let saved = item.saved { parts.append("Saved \(saved.formatted(date: .abbreviated, time: .omitted))") }
        if item.clear { parts.append("http") }
        return parts.joined(separator: " · ")
    }

    private func reveal(_ item: Kept) {
        if shown[item.id] != nil { shown[item.id] = nil; return }
        Vault.prove("Show the password for \(item.host)") { ok in
            guard ok, let secret = Vault.secret(of: item) else { return }
            shown[item.id] = secret
        }
    }

    private func forget(_ item: Kept) {
        Vault.forget(item)
        browser.forgot(item)
        shown[item.id] = nil
        kept = Vault.all()
        if site != nil, listed.isEmpty { site = nil }
    }
}

// MARK: - settings

struct SettingsView: View {
    @EnvironmentObject var browser: Browser
    @EnvironmentObject var history: History
    @Environment(\.dismiss) private var dismiss
    @State private var account = "Checking…"

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Dark Pages", isOn: $browser.darkPages)
                    Toggle("Text Only in Reading Mode", isOn: $browser.textOnly)
                } footer: {
                    Text("Dark Pages turns every light site dark; pictures and video keep their colours. Text Only leaves just the words when you open reading mode.")
                }
                Section("iCloud") {
                    LabeledContent("Account", value: account)
                    Text("Bookmarks and passwords are the same here and in Brou on your Mac.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section {
                    Button("Clear History", role: .destructive) { history.clear() }
                }
                Section {
                    Text("Brou for iPhone and iPad, by Victor Correal. Based on Search by Office Commun (MIT License).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .task {
                let status = try? await CKContainer(identifier: CloudSync.container).accountStatus()
                account = switch status {
                case .available: "Signed in"
                case .noAccount: "Not signed in to iCloud"
                case .restricted: "Restricted"
                case .temporarilyUnavailable: "Temporarily unavailable"
                default: "Unknown"
                }
            }
        }
    }
}
