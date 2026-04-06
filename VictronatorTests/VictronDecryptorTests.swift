import XCTest
@testable import Victronator

final class VictronDecryptorTests: XCTestCase {

    func testKeyMismatch() {
        let key = Data(repeating: 0xAA, count: 16)
        // First byte of payload (0xBB) doesn't match first byte of key (0xAA)
        let payload = Data([0xBB, 0x01, 0x02, 0x03])

        XCTAssertThrowsError(try VictronDecryptor.decrypt(
            encryptedPayload: payload, key: key, iv: 1
        )) { error in
            guard case VictronDecryptor.DecryptionError.keyMismatch = error else {
                XCTFail("Expected keyMismatch error")
                return
            }
        }
    }

    func testKeyMatch() {
        let key = Data(repeating: 0xAA, count: 16)
        // First byte matches key
        let payload = Data([0xAA, 0x01, 0x02, 0x03])

        // Should not throw - we can't verify the decrypted content without known test vectors,
        // but we verify it doesn't crash and returns data of the right length.
        let result = try? VictronDecryptor.decrypt(
            encryptedPayload: payload, key: key, iv: 42
        )

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.count, 3) // payload minus key check byte
    }

    func testEmptyPayloadAfterKeyByte() {
        let key = Data(repeating: 0xAA, count: 16)
        let payload = Data([0xAA]) // Only the key check byte

        let result = try? VictronDecryptor.decrypt(
            encryptedPayload: payload, key: key, iv: 0
        )

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.count, 0)
    }

    func testEmptyPayload() {
        let key = Data(repeating: 0xAA, count: 16)
        let payload = Data()

        XCTAssertThrowsError(try VictronDecryptor.decrypt(
            encryptedPayload: payload, key: key, iv: 0
        ))
    }
}
