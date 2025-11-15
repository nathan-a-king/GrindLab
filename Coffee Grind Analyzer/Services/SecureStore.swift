import Foundation
import Security
import OSLog

final class SecureStore {
    enum SecureStoreError: Error {
        case unexpectedStatus(OSStatus)
    }

    static let shared = SecureStore(service: "com.nateking.GrindLab")

    private let service: String
    private let logger = Logger(subsystem: "com.nateking.GrindLab", category: "SecureStore")

    init(service: String) {
        self.service = service
    }

    func string(for key: String) throws -> String? {
        var query: [String: Any] = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            guard let data = item as? Data else { return nil }
            return String(data: data, encoding: .utf8)
        case errSecItemNotFound:
            return nil
        default:
            throw SecureStoreError.unexpectedStatus(status)
        }
    }

    func setString(_ value: String, for key: String) throws {
        var query = baseQuery(for: key)
        let data = Data(value.utf8)

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        switch status {
        case errSecSuccess:
            let attributes = [kSecValueData as String: data]
            let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw SecureStoreError.unexpectedStatus(updateStatus)
            }
        case errSecItemNotFound:
            query[kSecValueData as String] = data
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(query as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw SecureStoreError.unexpectedStatus(addStatus)
            }
        default:
            throw SecureStoreError.unexpectedStatus(status)
        }
    }

    func removeValue(for key: String) throws {
        let status = SecItemDelete(baseQuery(for: key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SecureStoreError.unexpectedStatus(status)
        }
    }

    func migrateString(from userDefaultsKey: String, to key: String) {
        guard let value = UserDefaults.standard.string(forKey: userDefaultsKey), !value.isEmpty else {
            return
        }

        do {
            try setString(value, for: key)
            UserDefaults.standard.removeObject(forKey: userDefaultsKey)
            logger.info("Migrated sensitive value for key \(key, privacy: .public) to Keychain")
        } catch {
            logger.error("Failed to migrate value for key \(key, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    private func baseQuery(for key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
    }
}
