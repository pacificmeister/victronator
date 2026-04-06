import Foundation
import CommonCrypto

/// Decrypts Victron BLE advertisement payloads using AES-128-CTR.
struct VictronDecryptor {

    enum DecryptionError: Error {
        case keyMismatch
        case cryptoError(CCCryptorStatus)
    }

    /// Decrypt an encrypted Victron BLE payload.
    /// - Parameters:
    ///   - encryptedPayload: The encrypted bytes (after the header). First byte is key check byte.
    ///   - key: 16-byte AES encryption key from VictronConnect.
    ///   - iv: 2-byte initialization vector from the advertisement header.
    /// - Returns: Decrypted payload data (excluding the key check byte).
    static func decrypt(encryptedPayload: Data, key: Data, iv: UInt16) throws -> Data {
        guard encryptedPayload.count >= 1 else { throw DecryptionError.keyMismatch }

        // Validate key: first byte of encrypted payload must match first byte of key
        guard encryptedPayload[encryptedPayload.startIndex] == key[key.startIndex] else {
            throw DecryptionError.keyMismatch
        }

        // The actual encrypted data starts after the key check byte
        let ciphertext = encryptedPayload.dropFirst()
        guard !ciphertext.isEmpty else { return Data() }

        // Build 16-byte CTR nonce: IV (2 bytes LE) + 14 zero bytes
        var nonce = Data(count: 16)
        nonce[0] = UInt8(iv & 0xFF)
        nonce[1] = UInt8(iv >> 8)

        // Pad ciphertext to 16 bytes (AES block size) for CommonCrypto
        var input = Data(ciphertext)
        let originalLength = input.count
        if input.count < 16 {
            input.append(Data(count: 16 - input.count))
        }

        var output = Data(count: input.count)
        var cryptor: CCCryptorRef?

        let createStatus = nonce.withUnsafeBytes { nonceBytes in
            key.withUnsafeBytes { keyBytes in
                CCCryptorCreateWithMode(
                    CCOperation(kCCEncrypt), // CTR mode: encrypt == decrypt
                    CCMode(kCCModeCTR),
                    CCAlgorithm(kCCAlgorithmAES),
                    CCPadding(ccNoPadding),
                    nonceBytes.baseAddress,
                    keyBytes.baseAddress,
                    key.count,
                    nil, 0, 0,
                    CCModeOptions(kCCModeOptionCTR_BE),
                    &cryptor
                )
            }
        }

        guard createStatus == kCCSuccess, let c = cryptor else {
            throw DecryptionError.cryptoError(createStatus)
        }

        defer { CCCryptorRelease(c) }

        var bytesWritten = 0
        let outputCount = output.count
        let updateStatus = input.withUnsafeBytes { inputBytes in
            output.withUnsafeMutableBytes { outputBytes in
                CCCryptorUpdate(
                    c,
                    inputBytes.baseAddress,
                    input.count,
                    outputBytes.baseAddress,
                    outputCount,
                    &bytesWritten
                )
            }
        }

        guard updateStatus == kCCSuccess else {
            throw DecryptionError.cryptoError(updateStatus)
        }

        // Return only the original-length portion (trim padding)
        return output.prefix(originalLength)
    }
}
