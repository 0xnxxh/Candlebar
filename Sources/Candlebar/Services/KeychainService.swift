import Foundation
import Security

final class KeychainService {
    private let service = "com.hoon.Candlebar"
    private let account = "binance"

    func loadCredentials() throws -> StoredAPIKey? {
        guard let data = try read(account: account) else {
            return nil
        }
        let payload = try JSONDecoder().decode(KeychainPayload.self, from: data)
        return StoredAPIKey(apiKey: payload.apiKey, secret: payload.secret)
    }

    func save(credentials: StoredAPIKey) throws {
        let payload = KeychainPayload(apiKey: credentials.apiKey, secret: credentials.secret)
        let data = try JSONEncoder().encode(payload)
        try delete()

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

    func delete() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        try Self.validateDeleteStatus(SecItemDelete(query as CFDictionary))
    }

    private func read(account: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        return try Self.data(item: item, status: status)
    }

    static func data(item: CFTypeRef?, status: OSStatus) throws -> Data? {
        guard status != errSecItemNotFound else {
            return nil
        }
        guard status == errSecSuccess else {
            throw KeychainError.unhandled(status)
        }
        guard let data = item as? Data else {
            throw KeychainError.invalidData
        }
        return data
    }

    static func validateDeleteStatus(_ status: OSStatus) throws {
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandled(status)
        }
    }
}

enum KeychainError: Error, LocalizedError {
    case invalidData
    case unhandled(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidData:
            "Invalid Keychain data"
        case .unhandled(let status):
            "Keychain error \(status)"
        }
    }
}

private struct KeychainPayload: Codable {
    var apiKey: String
    var secret: String
}
