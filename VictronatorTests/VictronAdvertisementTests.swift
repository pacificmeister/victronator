import XCTest
@testable import Victronator

final class VictronAdvertisementTests: XCTestCase {

    func testParseValidAdvertisement() {
        // Build raw manufacturer data:
        // [0xE1, 0x02] - company ID (Victron)
        // [0x10, 0x00] - prefix
        // [0xA3, 0x89] - model ID 0x89A3
        // [0x02]       - readout type (battery monitor)
        // [0x2A, 0x00] - IV = 42
        // [0xAA]       - encryption key byte 0
        // [0x01, 0x02, 0x03] - encrypted data
        let rawData = Data([
            0xE1, 0x02,         // company ID
            0x10, 0x00,         // prefix
            0xA3, 0x89,         // model ID
            0x02,               // readout type
            0x2A, 0x00,         // IV
            0xAA,               // key byte
            0x01, 0x02, 0x03    // encrypted
        ])

        let testId = UUID()
        let adv = VictronAdvertisement(rawManufacturerData: rawData, peripheralId: testId)

        XCTAssertNotNil(adv)
        XCTAssertEqual(adv?.modelId, 0x89A3)
        XCTAssertEqual(adv?.readoutType, 0x02)
        XCTAssertEqual(adv?.iv, 42)
        XCTAssertEqual(adv?.encryptionKeyByte, 0xAA)
        XCTAssertEqual(adv?.encryptedPayload.count, 4) // key byte + 3 encrypted bytes
        XCTAssertEqual(adv?.deviceType, .batteryMonitor)
        XCTAssertEqual(adv?.peripheralId, testId)
    }

    func testRejectNonVictron() {
        // Wrong manufacturer ID
        let rawData = Data([0x00, 0x00, 0x10, 0x00, 0xA3, 0x89, 0x02, 0x2A, 0x00, 0xAA])
        let adv = VictronAdvertisement(rawManufacturerData: rawData, peripheralId: UUID())
        XCTAssertNil(adv)
    }

    func testRejectTooShort() {
        let rawData = Data([0xE1, 0x02, 0x10, 0x00])
        let adv = VictronAdvertisement(rawManufacturerData: rawData, peripheralId: UUID())
        XCTAssertNil(adv)
    }

    func testSolarChargerType() {
        let rawData = Data([
            0xE1, 0x02,
            0x10, 0x00,
            0x00, 0xA0,
            0x01,           // solar charger
            0x01, 0x00,
            0xBB
        ])
        let adv = VictronAdvertisement(rawManufacturerData: rawData, peripheralId: UUID())
        XCTAssertEqual(adv?.deviceType, .solarCharger)
    }
}
