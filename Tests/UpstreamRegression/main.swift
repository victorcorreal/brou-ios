import Foundation
import Security

// Local Security adapter: the production Vault runs against synthetic items.
// Never call a real keychain or require an Apple account in this regression.
private var reads = 0
private let fixtures: [[String: Any]] = [
    [kSecAttrServer as String: "cms.example.com", kSecAttrAccount as String: "same", kSecAttrProtocol as String: kSecAttrProtocolHTTPS, kSecValuePersistentRef as String: Data([1]), kSecValueData as String: Data("secure".utf8)],
    [kSecAttrServer as String: "cms.example.com", kSecAttrAccount as String: "same", kSecAttrProtocol as String: kSecAttrProtocolHTTP, kSecValuePersistentRef as String: Data([2]), kSecValueData as String: Data("plain".utf8)],
    [kSecAttrServer as String: "example.com", kSecAttrAccount as String: "root", kSecAttrProtocol as String: kSecAttrProtocolHTTPS, kSecValuePersistentRef as String: Data([3]), kSecValueData as String: Data("root".utf8)],
]
func SecItemCopyMatching(_ query: CFDictionary, _ result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus {
    let q = query as! [String: Any]
    let selected = fixtures.filter { row in
        for key in [kSecAttrServer, kSecAttrAccount, kSecValuePersistentRef] {
            if let wanted = q[key as String] as? NSObject, wanted != row[key as String] as? NSObject { return false }
        }
        return true
    }
    guard !selected.isEmpty else { return errSecItemNotFound }
    if q[kSecReturnData as String] as? Bool == true {
        reads += 1
        result?.pointee = selected[0][kSecValueData as String] as! CFData
    } else {
        result?.pointee = selected.map { $0.filter { $0.key != kSecValueData as String } } as CFArray
    }
    return errSecSuccess
}
func SecItemUpdate(_ query: CFDictionary, _ attributes: CFDictionary) -> OSStatus { errSecSuccess }
func SecItemAdd(_ attributes: CFDictionary, _ result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus { errSecSuccess }
func SecItemDelete(_ query: CFDictionary) -> OSStatus { errSecSuccess }

func expect(_ condition: Bool, _ name: String) {
    if !condition { fputs("FAIL: \(name)\n", stderr); exit(1) }
    print("PASS: \(name)")
}
let rows = Vault.kept(for: "cms.example.com")
expect(rows.count == 2 && reads == 0, "listing CMS accounts reads attributes only")
expect(Vault.kept(for: "dev.example.com").isEmpty && reads == 0, "unknown siblings have no fallback or secret reads")
let plain = rows.first { $0.clear }!
let chosen = Vault.login(plain)
expect(chosen?.password == "plain" && chosen?.ref == Data([2]) && reads == 1, "selection reads exactly the chosen HTTP item despite same username")
expect(Vault.login(rows.first { !$0.clear }!)?.password == "secure" && reads == 2, "HTTPS item remains separate")
expect(Vault.kept(for: "www.example.com").map(\.user) == ["root"] && reads == 2, "www alias lists only root metadata")
expect(Vault.kept(for: "example.com").count == 1 && reads == 2, "parent excludes CMS accounts")
print("6 passed, 0 failed")
