import Foundation

/// Parsed Victron BLE advertisement from raw manufacturer data.
struct VictronAdvertisement {
    let peripheralId: UUID
    let modelId: UInt16
    let readoutType: UInt8
    let iv: UInt16
    let encryptionKeyByte: UInt8
    let encryptedPayload: Data // Includes the key check byte as first byte

    /// Parse from raw CoreBluetooth manufacturer data.
    /// The `CBAdvertisementDataManufacturerDataKey` Data includes the 2-byte company ID.
    init?(rawManufacturerData: Data, peripheralId: UUID) {
        // Minimum: 2 (company ID) + 2 (prefix) + 2 (model) + 1 (readout) + 2 (iv) + 1 (key byte) = 10
        guard rawManufacturerData.count >= 10 else { return nil }

        // Verify Victron manufacturer ID (little-endian: 0xE1, 0x02)
        guard rawManufacturerData[0] == 0xE1, rawManufacturerData[1] == 0x02 else { return nil }

        // Offsets relative to start of manufacturer data (after company ID at bytes 0-1)
        let base = 2

        // Skip prefix bytes (2 bytes at offset base+0, base+1)
        self.modelId = UInt16(rawManufacturerData[base + 2])
            | (UInt16(rawManufacturerData[base + 3]) << 8)

        self.readoutType = rawManufacturerData[base + 4]

        self.iv = UInt16(rawManufacturerData[base + 5])
            | (UInt16(rawManufacturerData[base + 6]) << 8)

        self.encryptionKeyByte = rawManufacturerData[base + 7]

        // Encrypted payload = key check byte + encrypted data
        self.encryptedPayload = rawManufacturerData.subdata(in: (base + 7)..<rawManufacturerData.count)

        self.peripheralId = peripheralId
    }

    /// The device category based on readout type.
    var deviceType: VictronConstants.ReadoutType? {
        VictronConstants.ReadoutType(rawValue: readoutType)
    }
}
