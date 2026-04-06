import Foundation
import SwiftUI

/// Persists per-device AES encryption keys to UserDefaults.
class KeyStore: ObservableObject {
    static let shared = KeyStore()

    private let defaults = UserDefaults.standard
    private let storageKey = "victronator.device_keys"

    /// Map of peripheral UUID string -> hex key string
    @Published private(set) var keys: [String: String] = [:]

    private init() {
        keys = defaults.dictionary(forKey: storageKey) as? [String: String] ?? [:]
    }

    /// Get the 16-byte encryption key for a device, if configured.
    func key(for deviceId: UUID) -> Data? {
        guard let hex = keys[deviceId.uuidString] else { return nil }
        guard let data = Data(hexString: hex), data.count == 16 else { return nil }
        return data
    }

    /// Check if a key is stored for this device.
    func hasKey(for deviceId: UUID) -> Bool {
        keys[deviceId.uuidString] != nil
    }

    /// Store an encryption key (32-char hex string) for a device.
    /// Returns false if the hex string is invalid.
    @discardableResult
    func setKey(hexString: String, for deviceId: UUID) -> Bool {
        let cleaned = hexString.replacingOccurrences(of: " ", with: "").lowercased()
        guard let data = Data(hexString: cleaned), data.count == 16 else { return false }
        keys[deviceId.uuidString] = cleaned
        save()
        return true
    }

    /// Remove the key for a device.
    func removeKey(for deviceId: UUID) {
        keys.removeValue(forKey: deviceId.uuidString)
        save()
    }

    private func save() {
        defaults.set(keys, forKey: storageKey)
    }
}
