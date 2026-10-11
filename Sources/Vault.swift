import Foundation
import LocalAuthentication
import Security

// Passwords in iCloud Keychain, the same items Search for Mac keeps
// (VaultCloud.swift there; the format is in Victor's SINCRONIZACION.md):
// internet passwords labelled "Search", in the group
// E653G759EN.cat.correal.search, synchronizable. iCloud Keychain carries them
// between the two apps, encrypted end to end.

struct Login: Identifiable, Hashable {
    var host: String
    var user: String
    var password: String
    var used: Date?
    /// Kept from a page sent in the clear, over plain http. Only these are
    /// offered on such a page, as on the Mac.
    var clear = false

    var id: String { host + "\u{1}" + user }
}

/// One item as a list needs it: no secret.
struct Kept: Identifiable, Hashable {
    var host: String
    var user: String
    var used: Date?
    var clear = false

    var id: String { host + "\u{1}" + user }
}

enum Vault {
    static let group = "E653G759EN.cat.correal.search"
    private static let label = "Search"

    private static func base(_ extra: [String: Any] = [:]) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrLabel as String: label,
            kSecAttrAccessGroup as String: group,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
        ]
        extra.forEach { query[$0] = $1 }
        return query
    }

    // MARK: - reading

    static func all() -> [Kept] {
        rows([:]).compactMap(kept(from:))
            .sorted { $0.host == $1.host ? $0.user < $1.user : $0.host < $1.host }
    }

    /// What is kept for a page's host: the host itself and the rest of its
    /// site (accounts.example.com for example.com and the other way round).
    static func logins(for host: String, clear: Bool) -> [Login] {
        let site = registrable(host)
        return rows([:])
            .filter { ($0[kSecAttrServer as String] as? String).map { registrable($0) == site } ?? false }
            .compactMap(login(from:))
            .filter { !clear || $0.clear }
            .sorted { ($0.used ?? .distantPast) > ($1.used ?? .distantPast) }
    }

    static func secret(of kept: Kept) -> String? {
        secret(host: kept.host, user: kept.user)
    }

    private static func rows(_ extra: [String: Any]) -> [[String: Any]] {
        var query = base(extra)
        query[kSecReturnAttributes as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitAll
        var out: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess,
              let rows = out as? [[String: Any]]
        else { return [] }
        return rows
    }

    private static func secret(host: String, user: String) -> String? {
        var query = base([kSecAttrServer as String: host, kSecAttrAccount as String: user])
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func noted(_ row: [String: Any]) -> (used: Date?, clear: Bool) {
        let used = (row[kSecAttrComment as String] as? String)
            .flatMap(Double.init).map(Date.init(timeIntervalSince1970:))
        let clear = (row[kSecAttrProtocol as String] as? String) == (kSecAttrProtocolHTTP as String)
        return (used, clear)
    }

    private static func login(from row: [String: Any]) -> Login? {
        guard let host = row[kSecAttrServer as String] as? String,
              let user = row[kSecAttrAccount as String] as? String,
              let password = secret(host: host, user: user)
        else { return nil }
        let (used, clear) = noted(row)
        return Login(host: host, user: user, password: password, used: used, clear: clear)
    }

    private static func kept(from row: [String: Any]) -> Kept? {
        guard let host = row[kSecAttrServer as String] as? String,
              let user = row[kSecAttrAccount as String] as? String
        else { return nil }
        let (used, clear) = noted(row)
        return Kept(host: host, user: user, used: used, clear: clear)
    }

    // MARK: - writing

    @discardableResult
    static func save(host: String, user: String, password: String, used: Date? = nil, clear: Bool = false) -> Bool {
        guard !host.isEmpty, !password.isEmpty, let data = password.data(using: .utf8) else { return false }
        let identity = base([kSecAttrServer as String: host, kSecAttrAccount as String: user])
        var fields: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrLabel as String: label,
            kSecAttrAuthenticationType as String: kSecAttrAuthenticationTypeHTMLForm,
            kSecAttrProtocol as String: clear ? kSecAttrProtocolHTTP : kSecAttrProtocolHTTPS,
        ]
        if let used { fields[kSecAttrComment as String] = String(used.timeIntervalSince1970) }
        let status = SecItemUpdate(identity as CFDictionary, fields as CFDictionary)
        if status == errSecSuccess { return true }
        guard status == errSecItemNotFound else { return false }
        var fresh = identity.merging(fields) { _, new in new }
        fresh[kSecAttrSynchronizable as String] = kCFBooleanTrue
        fresh[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
        return SecItemAdd(fresh as CFDictionary, nil) == errSecSuccess
    }

    static func touch(_ login: Login) {
        save(host: login.host, user: login.user, password: login.password, used: Date(), clear: login.clear)
    }

    static func forget(host: String, user: String) {
        SecItemDelete(base([kSecAttrServer as String: host, kSecAttrAccount as String: user]) as CFDictionary)
    }

    /// Whether this exact password is already kept for this account.
    static func holds(host: String, user: String, password: String) -> Bool {
        secret(host: host, user: user) == password
    }

    // MARK: - showing one

    /// A password is shown only to the phone's owner: Face ID or the passcode.
    static func prove(_ reason: String, _ done: @escaping (Bool) -> Void) {
        let context = LAContext()
        var trouble: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &trouble) else {
            done(true)
            return
        }
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { ok, _ in
            DispatchQueue.main.async { done(ok) }
        }
    }

    // MARK: - the site behind a host

    /// example.com for www.example.com and accounts.example.com; bbc.co.uk
    /// stays bbc.co.uk.
    static func registrable(_ host: String) -> String {
        let labels = host.lowercased().split(separator: ".").map(String.init)
        guard labels.count > 2 else { return labels.joined(separator: ".") }
        if host.allSatisfy({ $0.isNumber || $0 == "." }) { return host }
        let lastTwo = labels.suffix(2).joined(separator: ".")
        let twoLevel: Set<String> = ["co.uk", "org.uk", "ac.uk", "gov.uk", "com.au", "net.au", "org.au",
                                     "co.jp", "co.nz", "com.br", "com.mx", "com.ar", "com.es", "nom.es",
                                     "org.es", "gob.es", "co.in", "com.tr", "co.za", "com.cn"]
        return twoLevel.contains(lastTwo) ? labels.suffix(3).joined(separator: ".") : lastTwo
    }
}
