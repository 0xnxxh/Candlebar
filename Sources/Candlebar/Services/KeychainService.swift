import Foundation
import Security

final class KeychainService {
    private let service = "com.hoon.Candlebar"
    private let account = "binance"

    func loadCredentials() -> StoredAPIKey? {
        guard let data = read(account: account),
              let payload = try? JSONDecoder().decode(KeychainPayload.self, from: data) else {
            return nil
        }
        return StoredAPIKey(apiKey: payload.apiKey, secret: payload.secret)
    }

    func save(credentials: StoredAPIKey) throws {
        let payload = KeychainPayload(apiKey: credentials.apiKey, secret: credentials.secret)
        let data = try JSONEncoder().encode(payload)
        delete()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unhandled(status)
        }
    }

    func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }

    private func read(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else {
            return nil
        }
        return item as? Data
    }
}

enum KeychainError: Error, LocalizedError {
    case unhandled(OSStatus)

    var errorDescription: String? {
        switch self {
        case .unhandled(let status):
            "Keychain error \(status)"
        }
    }
}

private struct KeychainPayload: Codable {
    var apiKey: String
    var secret: String
}
